// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

use super::{
    auth::AllowedPeersUpdatable, metrics::Metrics, server::Server, Handle, Randomness,
    RandomnessEventLoop, RandomnessMessage, RandomnessServer,
};
use anemo::codegen::InboundRequestLayer;
use anemo_tower::auth::AllowedService;
use anemo_tower::rate_limit;
use std::{collections::HashSet, sync::Arc};

#[cfg(feature = "use-mysocial")]
use mysocial_config::p2p::RandomnessConfig;
#[cfg(feature = "use-mysocial")]
use mysocial_types::{base_types::AuthorityName, crypto::RandomnessRound};

#[cfg(not(feature = "use-mysocial"))]
use sui_config::p2p::RandomnessConfig;
#[cfg(not(feature = "use-mysocial"))]
use sui_types::{base_types::AuthorityName, crypto::RandomnessRound};

use tokio::sync::{mpsc, oneshot};

pub struct Builder {
    config: Option<RandomnessConfig>,
    metrics: Option<Metrics>,
    name: Option<AuthorityName>,
    randomness_tx: Option<mpsc::Sender<(u64, RandomnessRound, Vec<u8>)>>,
}

impl Builder {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        Self {
            config: None,
            metrics: None,
            name: None,
            randomness_tx: None,
        }
    }

    pub fn config(mut self, config: RandomnessConfig) -> Self {
        self.config = Some(config);
        self
    }

    pub fn with_metrics(mut self, registry: &prometheus::Registry) -> Self {
        self.metrics = Some(Metrics::enabled(registry));
        self
    }

    pub fn name(mut self, name: AuthorityName) -> Self {
        self.name = Some(name);
        self
    }

    pub fn randomness_tx(
        mut self,
        randomness_tx: mpsc::Sender<(u64, RandomnessRound, Vec<u8>)>,
    ) -> Self {
        self.randomness_tx = Some(randomness_tx);
        self
    }

    pub fn build(self) -> (UnstartedRandomness, RandomnessServer<impl Randomness>) {
        let randomness_config = self.config.clone().unwrap_or_default();
        let (builder, server) = self.build_internal();
        let mut randomness_server = RandomnessServer::new(server);

        // Apply auth layer
        let auth_layer = AllowedPeersUpdatable::new(Arc::new(HashSet::new()));
        let auth_service = AllowedService::new(auth_layer.clone());
        randomness_server = randomness_server.add_layer_for_send_signatures(auth_service);

        // Apply rate limits from configuration as needed.
        if let Some(limit) = randomness_config.send_signatures_rate_limit {
            randomness_server = randomness_server.add_layer_for_send_signatures(
                InboundRequestLayer::new(rate_limit::RateLimitLayer::new(
                    governor::Quota::per_second(limit),
                    rate_limit::WaitMode::Block,
                )),
            );
        }

        (builder, randomness_server)
    }

    pub(super) fn build_internal(self) -> (UnstartedRandomness, Server) {
        let Builder {
            config,
            metrics,
            name,
            randomness_tx,
        } = self;
        let config = config.unwrap_or_default();
        let name = name.expect("randomness name is required");
        let metrics = metrics.unwrap_or_else(Metrics::disabled);
        let randomness_tx = randomness_tx.expect("randomness_tx is required");

        let (sender, mailbox) = mpsc::channel(config.mailbox_capacity());
        let weak_sender = sender.downgrade();

        let handle = Handle { sender };

        let server = Server {
            mailbox_sender: weak_sender.clone(),
        };

        (
            UnstartedRandomness {
                name,
                config,
                mailbox,
                weak_sender,
                metrics,
                randomness_tx,
            },
            server,
        )
    }
}

pub struct UnstartedRandomness {
    pub(super) name: AuthorityName,
    pub(super) config: RandomnessConfig,
    pub(super) mailbox: mpsc::Receiver<RandomnessMessage>,
    pub(super) weak_sender: mpsc::WeakSender<RandomnessMessage>,
    pub(super) metrics: Metrics,
    pub(super) randomness_tx: mpsc::Sender<(u64, RandomnessRound, Vec<u8>)>,
}

impl UnstartedRandomness {
    pub(super) fn build(self, network: anemo::Network) -> (RandomnessEventLoop, Handle) {
        let Self {
            name,
            config,
            mailbox,
            weak_sender,
            metrics,
            randomness_tx,
        } = self;

        let handle = Handle {
            sender: weak_sender
                .upgrade()
                .expect("sender should not be dropped at this point"),
        };

        (
            RandomnessEventLoop {
                name,
                config,
                mailbox,
                mailbox_sender: weak_sender,
                network,
                allowed_peers: AllowedPeersUpdatable::new(Arc::new(HashSet::new())),
                allowed_peers_set: HashSet::new(),
                metrics,
                randomness_tx,
                epoch: 0,
                authority_info: Arc::new(HashMap::new()),
                peer_share_ids: None,
                blocked_share_id_count: 0,
                dkg_output: None,
                aggregation_threshold: 0,
                highest_requested_round: Default::default(),
                send_tasks: Default::default(),
                round_request_time: Default::default(),
                future_epoch_partial_sigs: Default::default(),
                received_partial_sigs: Default::default(),
                completed_sigs: Default::default(),
                highest_completed_round: Default::default(),
            },
            handle,
        )
    }

    pub fn start(self, network: anemo::Network) -> Handle {
        let (event_loop, handle) = self.build(network);
        tokio::spawn(event_loop.start());

        handle
    }
}