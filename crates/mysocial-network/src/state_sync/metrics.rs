// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

use prometheus::{
    register_histogram_with_registry, register_int_gauge_with_registry, Histogram, IntGauge, Registry,
};
use std::time::Instant;

#[cfg(feature = "use-mysocial")]
use mysocial_types::messages_checkpoint::VerifiedCheckpoint;
#[cfg(not(feature = "use-mysocial"))]
use sui_types::messages_checkpoint::VerifiedCheckpoint;

#[derive(Clone, Debug)]
pub struct Metrics {
    highest_known_checkpoint: Option<IntGauge>,
    highest_verified_checkpoint: Option<IntGauge>,
    highest_synced_checkpoint: Option<IntGauge>,
    checkpoint_summary_age_ms: Option<Histogram>,
    checkpoint_summary_age_min: Option<Histogram>,
}

impl Metrics {
    pub fn enabled(registry: &Registry) -> Self {
        let metrics = Self {
            highest_known_checkpoint: Some(
                register_int_gauge_with_registry!(
                    "state_sync_highest_known_checkpoint",
                    "Highest checkpoint known to other peers",
                    registry,
                )
                .unwrap(),
            ),
            highest_verified_checkpoint: Some(
                register_int_gauge_with_registry!(
                    "state_sync_highest_verified_checkpoint",
                    "Highest checkpoint verified locally",
                    registry,
                )
                .unwrap(),
            ),
            highest_synced_checkpoint: Some(
                register_int_gauge_with_registry!(
                    "state_sync_highest_synced_checkpoint",
                    "Highest checkpoint contents synced locally",
                    registry,
                )
                .unwrap(),
            ),

            checkpoint_summary_age_ms: Some(
                register_histogram_with_registry!(
                    "checkpoint_summary_age_ms",
                    "Age of checkpoint summaries in milliseconds",
                    vec![
                        100.0, 500.0, 1000.0, 2000.0, 5000.0, 10_000.0, 20_000.0, 50_000.0,
                        100_000.0
                    ],
                    registry,
                )
                .unwrap(),
            ),

            checkpoint_summary_age_min: Some(
                register_histogram_with_registry!(
                    "checkpoint_summary_age_min",
                    "Age of checkpoint summaries in minutes",
                    vec![
                        0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0
                    ],
                    registry,
                )
                .unwrap(),
            ),
        };

        // Initialize metrics
        if let Some(gauge) = &metrics.highest_known_checkpoint {
            gauge.set(0);
        }
        if let Some(gauge) = &metrics.highest_verified_checkpoint {
            gauge.set(0);
        }
        if let Some(gauge) = &metrics.highest_synced_checkpoint {
            gauge.set(0);
        }

        metrics
    }

    pub fn disabled() -> Self {
        Self {
            highest_known_checkpoint: None,
            highest_verified_checkpoint: None,
            highest_synced_checkpoint: None,
            checkpoint_summary_age_ms: None,
            checkpoint_summary_age_min: None,
        }
    }

    pub fn set_highest_known_checkpoint(&self, sequence_number: u64) {
        if let Some(gauge) = &self.highest_known_checkpoint {
            gauge.set(sequence_number as i64);
        }
    }

    pub fn set_highest_verified_checkpoint(&self, sequence_number: u64) {
        if let Some(gauge) = &self.highest_verified_checkpoint {
            gauge.set(sequence_number as i64);
        }
    }

    pub fn set_highest_synced_checkpoint(&self, sequence_number: u64) {
        if let Some(gauge) = &self.highest_synced_checkpoint {
            gauge.set(sequence_number as i64);
        }
    }

    pub fn checkpoint_summary_age_metrics(&self) -> Option<(&Histogram, &Histogram)> {
        match (&self.checkpoint_summary_age_ms, &self.checkpoint_summary_age_min) {
            (Some(ms), Some(min)) => Some((ms, min)),
            _ => None,
        }
    }
}

impl Default for Metrics {
    fn default() -> Self {
        Self::disabled()
    }
}

pub trait VerifiedCheckpointExt {
    fn report_checkpoint_age(&self, ms_metric: &Histogram, min_metric: &Histogram);
}

impl VerifiedCheckpointExt for VerifiedCheckpoint {
    fn report_checkpoint_age(&self, ms_metric: &Histogram, min_metric: &Histogram) {
        if let Some(timestamp_ms) = self.timestamp_ms {
            let now = Instant::now();
            let now_ms = now
                .checked_duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_millis() as u64);

            if let Some(now_ms) = now_ms {
                if now_ms > timestamp_ms {
                    let age_ms = now_ms - timestamp_ms;
                    let age_min = age_ms as f64 / (1000.0 * 60.0);

                    ms_metric.observe(age_ms as f64);
                    min_metric.observe(age_min);
                }
            }
        }
    }
}