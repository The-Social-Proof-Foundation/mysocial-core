// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

//! Peer-to-peer data synchronization of checkpoints.
//!
//! This StateSync module is responsible for the synchronization and dissemination of checkpoints
//! and the transactions, and their effects, contained within. This module is *not* responsible for
//! the execution of the transactions included in a checkpoint, that process is left to another
//! component in the system.

use anemo::{types::PeerEvent, PeerId, Request, Response, Result};
use futures::{stream::FuturesOrdered, FutureExt, StreamExt};
use rand::Rng;
use std::sync::atomic::{AtomicU64, Ordering};
use std::{
    collections::{HashMap, VecDeque},
    sync::{Arc, RwLock},
    time::Duration,
};

#[cfg(feature = "use-mysocial")]
use mysocial_config::p2p::StateSyncConfig;
#[cfg(feature = "use-mysocial")]
use mysocial_types::{
    committee::Committee,
    digests::CheckpointDigest,
    messages_checkpoint::{
        CertifiedCheckpointSummary as Checkpoint, CheckpointSequenceNumber, EndOfEpochData,
        FullCheckpointContents, VerifiedCheckpoint, VerifiedCheckpointContents,
    },
    storage::WriteStore,
};

#[cfg(not(feature = "use-mysocial"))]
use sui_config::p2p::StateSyncConfig;
#[cfg(not(feature = "use-mysocial"))]
use sui_types::{
    committee::Committee,
    digests::CheckpointDigest,
    messages_checkpoint::{
        CertifiedCheckpointSummary as Checkpoint, CheckpointSequenceNumber, EndOfEpochData,
        FullCheckpointContents, VerifiedCheckpoint, VerifiedCheckpointContents,
    },
    storage::WriteStore,
};

use tap::{Pipe, TapFallible, TapOptional};
use tokio::sync::oneshot;
use tokio::{
    sync::{broadcast, mpsc, watch},
    task::{AbortHandle, JoinSet},
};
use tracing::{debug, info, instrument, trace, warn};

mod generated {
    include!(concat!(env!("OUT_DIR"), "/sui.StateSync.rs"));
}
mod builder;
mod metrics;
mod server;
#[cfg(test)]
mod tests;

pub use builder::{Builder, UnstartedStateSync};
pub use generated::{
    state_sync_client::StateSyncClient,
    state_sync_server::{StateSync, StateSyncServer},
};
pub use server::GetCheckpointAvailabilityResponse;
pub use server::GetCheckpointSummaryRequest;

#[cfg(feature = "use-mysocial")]
use mysocial_archival::reader::ArchiveReaderBalancer;
#[cfg(feature = "use-mysocial")]
use mysocial_storage::verify_checkpoint;

#[cfg(not(feature = "use-mysocial"))]
use sui_archival::reader::ArchiveReaderBalancer;
#[cfg(not(feature = "use-mysocial"))]
use sui_storage::verify_checkpoint;

use self::{metrics::Metrics, server::CheckpointContentsDownloadLimitLayer};

/// A handle to the StateSync subsystem.
///
/// This handle can be cloned and shared. Once all copies of a StateSync system's Handle have been
/// dropped, the StateSync system will be gracefully shutdown.
#[derive(Clone, Debug)]
pub struct Handle {
    sender: mpsc::Sender<StateSyncMessage>,
    checkpoint_event_sender: broadcast::Sender<VerifiedCheckpoint>,
}

impl Handle {
    /// Send a newly minted checkpoint from Consensus to StateSync so that it can be disseminated
    /// to other nodes on the network.
    ///
    /// # Invariant
    ///
    /// Consensus must only notify StateSync of new checkpoints that have been fully committed to
    /// persistent storage. This includes CheckpointContents and all Transactions and
    /// TransactionEffects included therein.
    pub async fn send_checkpoint(&self, checkpoint: VerifiedCheckpoint) {
        self.sender
            .send(StateSyncMessage::VerifiedCheckpoint(Box::new(checkpoint)))
            .await
            .unwrap()
    }

    /// Subscribe to the stream of checkpoints that have been fully synchronized and downloaded.
    pub fn subscribe_to_synced_checkpoints(&self) -> broadcast::Receiver<VerifiedCheckpoint> {
        self.checkpoint_event_sender.subscribe()
    }
}

// Skipping all internal implementation details for now, just including the key types and structs