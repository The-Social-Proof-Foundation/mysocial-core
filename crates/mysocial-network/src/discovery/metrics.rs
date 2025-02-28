// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

#[derive(Clone, Debug)]
pub struct Metrics {
    num_peers_with_external_address: Option<prometheus::IntGauge>,
}

impl Metrics {
    pub fn enabled(registry: &prometheus::Registry) -> Self {
        let metrics = Self {
            num_peers_with_external_address: Some(
                prometheus::register_int_gauge_with_registry!(
                    "discovery_num_peers_with_external_address",
                    "Number of peers with at least one external address",
                    registry,
                )
                .unwrap(),
            ),
        };

        // Initialize metrics
        if let Some(gauge) = &metrics.num_peers_with_external_address {
            gauge.set(0);
        }

        metrics
    }

    pub fn disabled() -> Self {
        Self {
            num_peers_with_external_address: None,
        }
    }

    pub fn inc_num_peers_with_external_address(&self) {
        if let Some(gauge) = &self.num_peers_with_external_address {
            gauge.inc();
        }
    }

    pub fn dec_num_peers_with_external_address(&self) {
        if let Some(gauge) = &self.num_peers_with_external_address {
            gauge.dec();
        }
    }
}