// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

//! This module provides aliases for commonly used types from sui-core
//! to ease the transition from sui-core to mysocial-core.

// Import sui-core and re-export to maintain compatibility
pub use sui_core;

// Specifically re-export AuthorityState which is commonly used
pub use sui_core::authority::AuthorityState;

// Re-export LiveObject which is used in restorer
pub use sui_core::authority::authority_store_tables::LiveObject;

// Re-export authority clients
pub use sui_core::authority_client::NetworkAuthorityClient;
pub use sui_core::authority_client::AuthorityAPI;
pub use sui_core::authority_client::AuthorityClient;

// Re-export transaction orchestrator
pub use sui_core::transaction_orchestrator::TransactiondOrchestrator;

// Re-export authority aggregator
pub use sui_core::authority_aggregator::AuthorityAggregator;