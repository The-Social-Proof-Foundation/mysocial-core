// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

use self::{auth::AllowedPeersUpdatable, metrics::Metrics};
use anemo::PeerId;
use anyhow::Result;
use fastcrypto::groups::bls12381;
use fastcrypto_tbls::{
    dkg_v1,
    nodes::PartyId,
    tbls::ThresholdBls,
    types::{ShareIndex, ThresholdBls12381MinSig},
};
use mysten_metrics::spawn_monitored_task;
use mysten_network::anemo_ext::NetworkExt;
use serde::{Deserialize, Serialize};
use std::{
    collections::{btree_map::BTreeMap, HashMap, HashSet},
    ops::Bound,
    sync::Arc,
    time::{self, Duration},
};

#[cfg(feature = "use-mysocial")]
use mysocial_config::p2p::RandomnessConfig;
#[cfg(feature = "use-mysocial")]
use mysocial_macros::fail_point_if;
#[cfg(feature = "use-mysocial")]
use mysocial_types::{
    base_types::AuthorityName,
    committee::EpochId,
    crypto::{RandomnessPartialSignature, RandomnessRound, RandomnessSignature},
};

#[cfg(not(feature = "use-mysocial"))]
use sui_config::p2p::RandomnessConfig;
#[cfg(not(feature = "use-mysocial"))]
use sui_macros::fail_point_if;
#[cfg(not(feature = "use-mysocial"))]
use sui_types::{
    base_types::AuthorityName,
    committee::EpochId,
    crypto::{RandomnessPartialSignature, RandomnessRound, RandomnessSignature},
};

use tokio::sync::{
    OnceCell, {mpsc, oneshot},
};
use tracing::{debug, error, info, instrument, warn};

mod auth;
mod builder;
mod generated {
    include!(concat!(env!("OUT_DIR"), "/sui.Randomness.rs"));
}
mod metrics;
mod server;
#[cfg(test)]
mod tests;

pub use builder::{Builder, UnstartedRandomness};
pub use generated::{
    randomness_client::RandomnessClient,
    randomness_server::{Randomness, RandomnessServer},
};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SendSignaturesRequest {
    epoch: EpochId,
    round: RandomnessRound,
    // BCS-serialized `RandomnessPartialSignature` values. We store raw bytes here to enable
    // defenses against too-large messages.
    // The protocol requires the signatures to be ordered by share index (as provided by fastcrypto).
    partial_sigs: Vec<Vec<u8>>,
    // If peer already has a full signature available for the round, it's provided here in lieu
    // of partial sigs.
    sig: Option<RandomnessSignature>,
}

/// A handle to the Randomness network subsystem.
///
/// This handle can be cloned and shared. Once all copies of a Randomness system's Handle have been
/// dropped, the Randomness system will be gracefully shutdown.
#[derive(Clone, Debug)]
pub struct Handle {
    sender: mpsc::Sender<RandomnessMessage>,
}

impl Handle {
    /// Transitions the Randomness system to a new epoch. Cancels all partial signature sends for
    /// prior epochs.
    pub fn update_epoch(
        &self,
        new_epoch: EpochId,
        authority_info: HashMap<AuthorityName, (PeerId, PartyId)>,
        dkg_output: dkg_v1::Output<bls12381::G2Element, bls12381::G2Element>,
        aggregation_threshold: u16,
        recovered_last_completed_round: Option<RandomnessRound>, // set to None if not starting up mid-epoch
    ) {
        self.sender
            .try_send(RandomnessMessage::UpdateEpoch(
                new_epoch,
                authority_info,
                dkg_output,
                aggregation_threshold,
                recovered_last_completed_round,
            ))
            .expect("RandomnessEventLoop mailbox should not overflow or be closed")
    }

    /// Begins transmitting partial signatures for the given epoch and round until completed.
    pub fn send_partial_signatures(&self, epoch: EpochId, round: RandomnessRound) {
        self.sender
            .try_send(RandomnessMessage::SendPartialSignatures(epoch, round))
            .expect("RandomnessEventLoop mailbox should not overflow or be closed")
    }

    /// Records the given round as complete, stopping any partial signature sends.
    pub fn complete_round(&self, epoch: EpochId, round: RandomnessRound) {
        self.sender
            .try_send(RandomnessMessage::CompleteRound(epoch, round))
            .expect("RandomnessEventLoop mailbox should not overflow or be closed")
    }

    /// Admin interface handler: generates partial signatures for the given round at the
    /// current epoch.
    pub fn admin_get_partial_signatures(
        &self,
        round: RandomnessRound,
        tx: oneshot::Sender<Vec<u8>>,
    ) {
        self.sender
            .try_send(RandomnessMessage::AdminGetPartialSignatures(round, tx))
            .expect("RandomnessEventLoop mailbox should not overflow or be closed")
    }

    /// Admin interface handler: injects partial signatures for the given round at the
    /// current epoch, skipping validity checks.
    pub fn admin_inject_partial_signatures(
        &self,
        authority_name: AuthorityName,
        round: RandomnessRound,
        sigs: Vec<RandomnessPartialSignature>,
        result_channel: oneshot::Sender<Result<()>>,
    ) {
        self.sender
            .try_send(RandomnessMessage::AdminInjectPartialSignatures(
                authority_name,
                round,
                sigs,
                result_channel,
            ))
            .expect("RandomnessEventLoop mailbox should not overflow or be closed")
    }

    /// Admin interface handler: injects full signature for the given round at the
    /// current epoch, skipping validity checks.
    pub fn admin_inject_full_signature(
        &self,
        round: RandomnessRound,
        sig: RandomnessSignature,
        result_channel: oneshot::Sender<Result<()>>,
    ) {
        self.sender
            .try_send(RandomnessMessage::AdminInjectFullSignature(
                round,
                sig,
                result_channel,
            ))
            .expect("RandomnessEventLoop mailbox should not overflow or be closed")
    }

    // For testing.
    pub fn new_stub() -> Self {
        let (sender, mut receiver) = mpsc::channel(1);
        // Keep receiver open until all senders are closed.
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    m = receiver.recv() => {
                        if m.is_none() {
                            break;
                        }
                    },
                }
            }
        });
        Self { sender }
    }
}

#[derive(Debug)]
enum RandomnessMessage {
    UpdateEpoch(
        EpochId,
        HashMap<AuthorityName, (PeerId, PartyId)>,
        dkg_v1::Output<bls12381::G2Element, bls12381::G2Element>,
        u16,                     // aggregation_threshold
        Option<RandomnessRound>, // recovered_highest_completed_round
    ),
    SendPartialSignatures(EpochId, RandomnessRound),
    CompleteRound(EpochId, RandomnessRound),
    ReceiveSignatures(
        PeerId,
        EpochId,
        RandomnessRound,
        Vec<Vec<u8>>,
        Option<RandomnessSignature>,
    ),
    MaybeIgnoreByzantinePeer(EpochId, PeerId),
    AdminGetPartialSignatures(RandomnessRound, oneshot::Sender<Vec<u8>>),
    AdminInjectPartialSignatures(
        AuthorityName,
        RandomnessRound,
        Vec<RandomnessPartialSignature>,
        oneshot::Sender<Result<()>>,
    ),
    AdminInjectFullSignature(
        RandomnessRound,
        RandomnessSignature,
        oneshot::Sender<Result<()>>,
    ),
}

// Skipping internal implementation for brevity