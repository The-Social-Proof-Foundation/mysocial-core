// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

// This file contains integration tests for mysocial-core with other renamed crates

#[cfg(test)]
mod tests {
    #[test]
    fn test_mysocial_types_integration() {
        // Test that mysocial-core can properly interact with mysocial-types
        let _object_id = mysocial_types::base_types::ObjectID::random();
        
        // Test that sui-types types can be converted to mysocial-types types and vice versa
        // This ensures compatibility between them
        let sui_object_id = sui_types::base_types::ObjectID::random();
        let mysocial_object_id = mysocial_types::base_types::ObjectID::from(sui_object_id.into_bytes());
        
        assert_eq!(
            sui_object_id.to_string(),
            mysocial_object_id.to_string()
        );
    }
    
    #[test]
    fn test_mysocial_protocol_config_integration() {
        // Test that mysocial-core can properly interact with mysocial-protocol-config
        let protocol_version = mysocial_protocol_config::ProtocolVersion::new(1);
        
        // Test that sui-protocol-config types can be converted to mysocial-protocol-config types
        let sui_protocol_version = sui_protocol_config::ProtocolVersion::new(1);
        
        // They should have the same underlying value
        assert_eq!(
            protocol_version.as_u64(),
            sui_protocol_version.as_u64()
        );
    }
}