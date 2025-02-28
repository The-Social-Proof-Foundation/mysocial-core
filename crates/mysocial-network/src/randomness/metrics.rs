// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

use prometheus::{
    register_histogram_with_registry, register_int_counter_with_registry,
    register_int_gauge_with_registry, Histogram, IntCounter, IntGauge, Registry,
};
use std::{cell::RefCell, time::Duration};
use sui_types::crypto::RandomnessRound;

#[derive(Clone, Debug)]
pub struct Metrics {
    epoch: Option<IntGauge>,
    num_rounds_pending: Option<IntGauge>,
    num_ignored_byzantine_peers: Option<IntCounter>,
    round_completion_sequence: Option<IntGauge>,
    round_generation_latency: Option<Histogram>,
    round_observation_latency: Option<Histogram>,
}

thread_local! {
    static LAST_COMPLETED_ROUND: RefCell<u64> = RefCell::new(0);
}

impl Metrics {
    pub fn enabled(registry: &Registry) -> Self {
        let metrics = Self {
            epoch: Some(
                register_int_gauge_with_registry!(
                    "randomness_epoch",
                    "Current epoch for randomness generation",
                    registry,
                )
                .unwrap(),
            ),

            num_rounds_pending: Some(
                register_int_gauge_with_registry!(
                    "randomness_num_rounds_pending",
                    "Number of rounds pending randomness",
                    registry,
                )
                .unwrap(),
            ),

            num_ignored_byzantine_peers: Some(
                register_int_counter_with_registry!(
                    "randomness_num_ignored_byzantine_peers",
                    "Number of peers that exhibited Byzantine behavior and are now ignored",
                    registry,
                )
                .unwrap(),
            ),

            round_completion_sequence: Some(
                register_int_gauge_with_registry!(
                    "randomness_round_completion_sequence",
                    "Highest round for which randomness was completed",
                    registry,
                )
                .unwrap(),
            ),

            round_generation_latency: Some(
                register_histogram_with_registry!(
                    "randomness_round_generation_latency",
                    "Time to generate randomness for a round",
                    // exponential buckets from 0.01s to 1000s (16.6min)
                    vec![0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0],
                    registry,
                )
                .unwrap(),
            ),

            round_observation_latency: Some(
                register_histogram_with_registry!(
                    "randomness_round_observation_latency",
                    "Time to observe other nodes' randomness for a round",
                    // exponential buckets from 0.01s to 1000s (16.6min)
                    vec![0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0],
                    registry,
                )
                .unwrap(),
            ),
        };

        // Initialize metrics
        if let Some(gauge) = &metrics.num_rounds_pending {
            gauge.set(0);
        }
        if let Some(counter) = &metrics.num_ignored_byzantine_peers {
            counter.reset();
        }

        metrics
    }

    pub fn disabled() -> Self {
        Self {
            epoch: None,
            num_rounds_pending: None,
            num_ignored_byzantine_peers: None,
            round_completion_sequence: None,
            round_generation_latency: None,
            round_observation_latency: None,
        }
    }

    pub fn set_epoch(&self, epoch: u64) {
        if let Some(gauge) = &self.epoch {
            gauge.set(epoch as i64);
        }
    }

    pub fn num_rounds_pending(&self) -> Option<i64> {
        self.num_rounds_pending.as_ref().map(|g| g.get())
    }

    pub fn set_num_rounds_pending(&self, num_rounds: i64) {
        if let Some(gauge) = &self.num_rounds_pending {
            gauge.set(num_rounds);
        }
    }

    pub fn inc_num_ignored_byzantine_peers(&self) {
        if let Some(counter) = &self.num_ignored_byzantine_peers {
            counter.inc();
        }
    }

    pub fn record_completed_round(&self, round: RandomnessRound) {
        if let Some(gauge) = &self.round_completion_sequence {
            LAST_COMPLETED_ROUND.with(|last| {
                let mut last = last.borrow_mut();
                if round.0 > *last {
                    gauge.set(round.0 as i64);
                    *last = round.0;
                }
            });
        }
    }

    pub fn round_generation_latency_metric(&self) -> Option<&Histogram> {
        self.round_generation_latency.as_ref()
    }

    pub fn round_observation_latency_metric(&self) -> Option<&Histogram> {
        self.round_observation_latency.as_ref()
    }
}

impl Default for Metrics {
    fn default() -> Self {
        Self::disabled()
    }
}