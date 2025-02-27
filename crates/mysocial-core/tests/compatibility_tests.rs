// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

// This file contains tests to ensure mysocial-core and sui-core compatibility

#[cfg(test)]
mod tests {
    #[test]
    fn test_mysocial_core_can_be_imported() {
        // This test simply verifies that mysocial-core can be imported successfully
        // If there's any issue with dependencies or module structure, this test will fail
        let _core = mysocial_core::authority::AuthorityState;
    }

    #[test]
    fn test_both_sui_core_and_mysocial_core_can_be_imported() {
        // Verify that both sui-core and mysocial-core can be imported in the same codebase
        let _sui_core = sui_core::authority::AuthorityState;
        let _mysocial_core = mysocial_core::authority::AuthorityState;
        
        // They should be the same type since we're using the same package name
        assert_eq!(
            std::any::type_name::<sui_core::authority::AuthorityState>(),
            std::any::type_name::<mysocial_core::authority::AuthorityState>()
        );
    }
}