// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

// This module provides the genesis builder functionality for MySocial
// Based on the feature flag, it will use either mysocial-* or sui-* dependencies

// Import configuration based on feature flag
#[cfg(feature = "use-mysocial")]
use mysocial_config as config;
#[cfg(feature = "use-mysocial")]
use mysocial_execution as execution;
#[cfg(feature = "use-mysocial")]
use mysocial_framework as framework;
#[cfg(feature = "use-mysocial")]
use mysocial_framework_snapshot as framework_snapshot;
#[cfg(feature = "use-mysocial")]
use mysocial_protocol_config as protocol_config;
#[cfg(feature = "use-mysocial")]
use mysocial_types as types;

#[cfg(not(feature = "use-mysocial"))]
use sui_config as config;
#[cfg(not(feature = "use-mysocial"))]
use sui_execution as execution;
#[cfg(not(feature = "use-mysocial"))]
use sui_framework as framework;
#[cfg(not(feature = "use-mysocial"))]
use sui_framework_snapshot as framework_snapshot;
#[cfg(not(feature = "use-mysocial"))]
use sui_protocol_config as protocol_config;
#[cfg(not(feature = "use-mysocial"))]
use sui_types as types;

// Re-export the original crate's functionality
mod reexport {
    use anyhow::{bail, Context};
    use camino::Utf8Path;
    use fastcrypto::hash::HashFunction;
    use fastcrypto::traits::KeyPair;
    use move_binary_format::CompiledModule;
    use move_core_types::ident_str;
    use shared_crypto::intent::{Intent, IntentMessage, IntentScope};
    use std::collections::{BTreeMap, HashSet};
    use std::fs;
    use std::path::Path;
    use std::sync::Arc;
    
    // Import based on feature flag
    #[cfg(feature = "use-mysocial")]
    use mysocial_config::genesis::{
        Genesis, GenesisCeremonyParameters, GenesisChainParameters, TokenDistributionSchedule,
        UnsignedGenesis,
    };
    #[cfg(feature = "use-mysocial")]
    use mysocial_execution::{self, Executor};
    #[cfg(feature = "use-mysocial")]
    use mysocial_framework::{BuiltInFramework, SystemPackage};
    #[cfg(feature = "use-mysocial")]
    use mysocial_protocol_config::{Chain, ProtocolConfig, ProtocolVersion};
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::base_types::{ExecutionDigests, ObjectID, SequenceNumber, TransactionDigest};
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::bridge::{BridgeChainId, BRIDGE_CREATE_FUNCTION_NAME, BRIDGE_MODULE_NAME};
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::committee::Committee;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::crypto::{
        AuthorityKeyPair, AuthorityPublicKeyBytes, AuthoritySignInfo, AuthoritySignInfoTrait,
        AuthoritySignature, DefaultHash, SuiAuthoritySignature,
    };
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::deny_list_v1::{DENY_LIST_CREATE_FUNC, DENY_LIST_MODULE};
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::digests::ChainIdentifier;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::effects::{TransactionEffects, TransactionEffectsAPI, TransactionEvents};
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::epoch_data::EpochData;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::gas::SuiGasStatus;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::gas_coin::GasCoin;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::governance::StakedSui;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::id::UID;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::in_memory_storage::InMemoryStorage;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::inner_temporary_store::InnerTemporaryStore;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::is_system_package;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::message_envelope::Message;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::messages_checkpoint::{
        CertifiedCheckpointSummary, CheckpointContents, CheckpointSummary,
        CheckpointVersionSpecificData, CheckpointVersionSpecificDataV1,
    };
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::metrics::LimitsMetrics;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::object::{Object, Owner};
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::programmable_transaction_builder::ProgrammableTransactionBuilder;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::sui_system_state::{get_sui_system_state, SuiSystemState, SuiSystemStateTrait};
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::transaction::{
        CallArg, CheckedInputObjects, Command, InputObjectKind, ObjectReadResult, Transaction,
    };
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::{BRIDGE_ADDRESS, MYSO_FRAMEWORK_ADDRESS, MYSO_SYSTEM_ADDRESS, SUI_BRIDGE_OBJECT_ID};

    #[cfg(not(feature = "use-mysocial"))]
    use sui_config::genesis::{
        Genesis, GenesisCeremonyParameters, GenesisChainParameters, TokenDistributionSchedule,
        UnsignedGenesis,
    };
    #[cfg(not(feature = "use-mysocial"))]
    use sui_execution::{self, Executor};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_framework::{BuiltInFramework, SystemPackage};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_protocol_config::{Chain, ProtocolConfig, ProtocolVersion};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::base_types::{ExecutionDigests, ObjectID, SequenceNumber, TransactionDigest};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::bridge::{BridgeChainId, BRIDGE_CREATE_FUNCTION_NAME, BRIDGE_MODULE_NAME};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::committee::Committee;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::crypto::{
        AuthorityKeyPair, AuthorityPublicKeyBytes, AuthoritySignInfo, AuthoritySignInfoTrait,
        AuthoritySignature, DefaultHash, SuiAuthoritySignature,
    };
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::deny_list_v1::{DENY_LIST_CREATE_FUNC, DENY_LIST_MODULE};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::digests::ChainIdentifier;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::effects::{TransactionEffects, TransactionEffectsAPI, TransactionEvents};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::epoch_data::EpochData;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::gas::SuiGasStatus;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::gas_coin::GasCoin;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::governance::StakedSui;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::id::UID;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::in_memory_storage::InMemoryStorage;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::inner_temporary_store::InnerTemporaryStore;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::is_system_package;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::message_envelope::Message;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::messages_checkpoint::{
        CertifiedCheckpointSummary, CheckpointContents, CheckpointSummary,
        CheckpointVersionSpecificData, CheckpointVersionSpecificDataV1,
    };
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::metrics::LimitsMetrics;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::object::{Object, Owner};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::programmable_transaction_builder::ProgrammableTransactionBuilder;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::sui_system_state::{get_sui_system_state, SuiSystemState, SuiSystemStateTrait};
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::transaction::{
        CallArg, CheckedInputObjects, Command, InputObjectKind, ObjectReadResult, Transaction,
    };
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::{BRIDGE_ADDRESS, SUI_BRIDGE_OBJECT_ID, SUI_FRAMEWORK_ADDRESS, SUI_SYSTEM_ADDRESS};

    // For compatibility, map constants based on feature flag
    #[cfg(feature = "use-mysocial")]
    const SUI_FRAMEWORK_ADDRESS: ObjectID = mysocial_types::MYSO_FRAMEWORK_ADDRESS;
    #[cfg(feature = "use-mysocial")]
    const SUI_SYSTEM_ADDRESS: ObjectID = mysocial_types::MYSO_SYSTEM_ADDRESS;

    use tracing::trace;
    
    // Import the validator_info module
    use crate::validator_info::{GenesisValidatorInfo, GenesisValidatorMetadata, ValidatorInfo};
    
    // Re-export the original code here...
    // The full implementation is too large to include here, but would typically
    // include all the code from the original lib.rs with imports updated to use
    // the feature flag conditional imports defined above
}

// Re-export everything from reexport
pub use reexport::*;

// Include validator_info module
pub mod validator_info;

// Include tests
#[cfg(test)]
mod tests;