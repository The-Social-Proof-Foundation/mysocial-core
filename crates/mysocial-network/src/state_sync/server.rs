// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

use std::{
    collections::HashMap,
    sync::{Arc, RwLock},
    time::{Duration, Instant},
};

use anemo::{Request, Response, Result};
use anyhow::anyhow;
use tokio::sync::mpsc;

#[cfg(feature = "use-mysocial")]
use mysocial_types::{
    digests::CheckpointDigest,
    messages_checkpoint::{
        CertifiedCheckpointSummary, CheckpointContentsDigest, CheckpointSequenceNumber,
        FullCheckpointContents,
    },
    storage::WriteStore,
};

#[cfg(not(feature = "use-mysocial"))]
use sui_types::{
    digests::CheckpointDigest,
    messages_checkpoint::{
        CertifiedCheckpointSummary, CheckpointContentsDigest, CheckpointSequenceNumber,
        FullCheckpointContents,
    },
    storage::WriteStore,
};

use super::{GetCheckpointSummaryRequest, PeerHeights, StateSync, StateSyncMessage};

#[derive(Debug, Clone)]
pub struct GetCheckpointAvailabilityResponse {
    pub highest_synced_checkpoint: CertifiedCheckpointSummary,
    pub lowest_available_checkpoint: CheckpointSequenceNumber,
}

#[derive(Clone)]
pub struct Server<S> {
    pub(super) store: S,
    pub(super) peer_heights: Arc<RwLock<PeerHeights>>,
    pub(super) sender: mpsc::WeakSender<StateSyncMessage>,
}

/// A middleware layer that limits downloads per checkpoint
#[derive(Debug, Clone)]
pub struct CheckpointContentsDownloadLimitLayer {
    maximum: usize,
    last_prune: Instant,
    requests_per_checkpoint: Arc<RwLock<HashMap<CheckpointContentsDigest, usize>>>,
}

impl CheckpointContentsDownloadLimitLayer {
    pub fn new(maximum: usize) -> Self {
        Self {
            maximum,
            last_prune: Instant::now(),
            requests_per_checkpoint: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn maybe_prune_map(&self) {
        if self.last_prune.elapsed() > Duration::from_secs(300) {
            self.requests_per_checkpoint.write().unwrap().clear();
        }
    }
}

// Implementation of the StateSync trait for the Server struct - simplified for brevity
impl<S> StateSync for Server<S>
where
    S: WriteStore + Clone + Send + Sync + 'static,
{
    async fn push_checkpoint_summary(
        &self,
        request: Request<CertifiedCheckpointSummary>,
    ) -> Result<Response<()>> {
        // Simplified implementation
        let peer_id = request
            .peer_id()
            .ok_or_else(|| anemo::rpc::Status::internal("missing peer_id"))?;
        let checkpoint = request.into_inner();

        self.peer_heights
            .write()
            .unwrap()
            .update_peer_info(peer_id, checkpoint, None);

        if let Some(sender) = self.sender.upgrade() {
            let _ = sender.try_send(StateSyncMessage::StartSyncJob);
        }

        Ok(Response::new(()))
    }

    async fn get_checkpoint_summary(
        &self,
        request: Request<GetCheckpointSummaryRequest>,
    ) -> Result<Response<Option<CertifiedCheckpointSummary>>> {
        // Simplified implementation
        let checkpoint = match request.into_inner() {
            GetCheckpointSummaryRequest::Latest => {
                self.store.get_highest_synced_checkpoint().ok()
            }
            GetCheckpointSummaryRequest::BySequenceNumber(seq) => {
                self.store.get_checkpoint_by_sequence_number(seq)
            }
            GetCheckpointSummaryRequest::ByDigest(digest) => {
                self.store.get_checkpoint_by_digest(&digest)
            }
        };

        Ok(Response::new(checkpoint))
    }

    async fn get_checkpoint_contents(
        &self,
        request: Request<CheckpointContentsDigest>,
    ) -> Result<Response<Option<FullCheckpointContents>>> {
        // Simplified implementation
        let digest = request.into_inner();
        let contents = self.store.get_full_checkpoint_contents(&digest);
        Ok(Response::new(contents))
    }

    async fn get_checkpoint_availability(
        &self,
        _request: Request<()>,
    ) -> Result<Response<GetCheckpointAvailabilityResponse>> {
        let highest_synced_checkpoint = self
            .store
            .get_highest_synced_checkpoint()
            .map_err(|_| anemo::rpc::Status::internal("Failed to get highest synced checkpoint"))?;

        // For simplicity, using a default lowest checkpoint of 0
        let lowest_available_checkpoint = 0;

        Ok(Response::new(GetCheckpointAvailabilityResponse {
            highest_synced_checkpoint,
            lowest_available_checkpoint: CheckpointSequenceNumber::from(lowest_available_checkpoint),
        }))
    }
}