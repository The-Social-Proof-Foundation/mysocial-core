// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

use anemo::{Request, Response, Result};
use tokio::sync::mpsc;

use super::{Randomness, RandomnessMessage, SendSignaturesRequest};

#[derive(Clone)]
pub struct Server {
    pub(super) mailbox_sender: mpsc::WeakSender<RandomnessMessage>,
}

impl Randomness for Server {
    async fn send_signatures(
        &self,
        request: Request<SendSignaturesRequest>,
    ) -> Result<Response<()>> {
        let peer_id = request
            .peer_id()
            .ok_or_else(|| anemo::rpc::Status::internal("missing peer_id"))?;
        let req = request.into_inner();
        let epoch = req.epoch;
        let round = req.round;

        // Upgrade weak sender to strong reference
        let Some(sender) = self.mailbox_sender.upgrade() else {
            return Err(anemo::rpc::Status::internal(
                "randomness event loop has shut down",
            ));
        };

        // Try to send the message to the event loop
        if let Err(e) = sender.try_send(RandomnessMessage::ReceiveSignatures(
            peer_id,
            epoch,
            round,
            req.partial_sigs,
            req.sig,
        )) {
            return Err(anemo::rpc::Status::internal(format!(
                "failed to forward partial signatures: {e}"
            )));
        }

        Ok(Response::new(()))
    }
}