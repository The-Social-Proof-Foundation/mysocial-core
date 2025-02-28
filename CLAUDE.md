# MySocial Renaming Guidelines and Compatibility

This document outlines the approach taken for renaming the Sui codebase to MySocial, including compatibility strategies, naming conventions, and best practices for working with the code during and after the transition.

## Progress Update

We've made significant progress in implementing the MySocial rebranding across several key modules:

### Updated Modules
- **sui-move**: Updated imports to use mysocial-types and mysocial-protocol-config
- **sui-sdk**: Added compatibility with mysocial-types while maintaining original imports
- **sui-tool**: Comprehensive update to use mysocial-core, mysocial-protocol-config, and mysocial-types
- **test-cluster**: Updated core imports to use mysocial-core
- **sui-e2e-test**: Updated core imports and tests to use mysocial-core
- **sui-node**: Complete refactoring of imports to use mysocial-core and mysocial-types across the codebase
- **sui-transactional-test-runner**: Updated to use mysocial-core and mysocial-types for testing infrastructure
- **sui-snapshot**: Updated key imports to use mysocial-core, mysocial-types, and mysocial-protocol-config
- **sui-json-rpc-types**: Updated to use mysocial-types for core type definitions
- **sui-simulator**: Added mysocial-types to reexports and dependencies
- **sui-storage**: Updated key components to use mysocial-types
- **sui-config**: Updated node configuration to use mysocial-types
- **sui-json**: Updated core JSON processing to use mysocial-types
- **sui-keys**: Updated key management utilities to use mysocial-types
- **sui-indexer**: Updated to use mysocial-core by default via feature flags
- **sui-telemetry**: Updated to use mysocial-core's AuthorityState through the alias module
- **sui-benchmark**: Updated to use mysocial-core, mysocial-types, and mysocial-protocol-config
- **sui-cluster-test**: Updated to use mysocial-types for core data types
- **sui-replay**: Updated to use mysocial-core, mysocial-types, and mysocial-protocol-config

### Enhanced alias.rs Module
We've expanded the alias.rs module in mysocial-core to handle more commonly used types:
- AuthorityState
- LiveObject (used in restorer)
- Authority clients (NetworkAuthorityClient, AuthorityAPI, AuthorityClient)
- TransactiondOrchestrator
- AuthorityAggregator

This module provides a compatibility layer that makes transitioning between sui-core and mysocial-core seamless.

## 1. Package Naming Strategy

### Cargo Package Names

- **Package names in Cargo.toml files are kept as `sui-*` for backward compatibility**
- Example: The `mysocial-types` directory still uses package name `sui-types` in its Cargo.toml
- This allows existing code and dependencies to continue working without disruption
- Directories are renamed to reflect the new `mysocial-*` naming pattern

```toml
# Example from mysocial-types/Cargo.toml
[package]
name = "sui-types" # Keeping name for compatibility with other crates
version = "0.1.0"
authors = ["The Social Proof Foundation <brandon@socialproof.foundation>"]
license = "Apache-2.0"
publish = false
edition = "2021"
```

## 2. Type and Constant Aliasing

### Backward Compatibility Aliases

- Old types and constants are aliased to new ones using Rust's module system
- This ensures existing code importing the old names continues to work
- Example from `mysocial-types/src/lib.rs`:

```rust
// Backward compatibility aliases
pub use mysocial_sdk_types_conversions as sui_sdk_types_conversions;
pub use mysocial_serde as sui_serde;
pub use mysocial_system_state as sui_system_state;

// Backward compatibility aliases for constants
pub use crate::MYSO_FRAMEWORK_ADDRESS as SUI_FRAMEWORK_ADDRESS;
pub use crate::MYSO_FRAMEWORK_PACKAGE_ID as SUI_FRAMEWORK_PACKAGE_ID;
pub use crate::MYSO_SYSTEM_ADDRESS as SUI_SYSTEM_ADDRESS;
// ...and so on
```

- Functions have also been aliased with deprecation notices:

```rust
#[deprecated(since = "1.0.0", note = "Use parse_myso_address instead")]
pub fn parse_sui_address(s: &str) -> anyhow::Result<SuiAddress> {
    parse_myso_address(s)
}
```

## 3. Import Examples

### Legacy Naming Import Examples

```rust
// Importing types with legacy naming
use sui_types::base_types::SuiAddress;
use sui_types::gas::GasCostSummary;
use sui_types::SUI_FRAMEWORK_ADDRESS;

// Importing functions with legacy naming
use sui_types::parse_sui_type_tag;
```

### New Naming Import Examples

```rust
// Importing types with new naming
use mysocial_types::base_types::SuiAddress;  // Name remains for compatibility
use mysocial_types::gas::GasCostSummary;
use mysocial_types::MYSO_FRAMEWORK_ADDRESS;  // New constant name

// Importing functions with new naming
use mysocial_types::parse_myso_type_tag;
```

## 4. Testing Compatibility Commands

To ensure compatibility between the renamed packages and code expecting the original names:

```bash
# Run all tests to verify internal compatibility
cargo test --all

# Test a specific crate that depends on both naming conventions
cargo test -p mysocial-types

# Test compile a dependent crate to check for import compatibility
cargo check -p some-dependent-crate

# Run integration tests that span multiple crates
cargo test --test "*_integration_test"

# Verify backwards compatibility with specific imports
cargo test --test compatibility_test

# Run the comprehensive compatibility test script
./crates/mysocial-core/tests/test_mysocial_core.sh
```

## 5. Best Practices for New Code

When writing new code that needs to work with both naming conventions:

1. **Use new names in new modules**: Always use the `mysocial-*` and `MYSO_*` naming in new code
   
2. **Explicitly handle aliases**: When defining new types or constants that might need aliases, add them at the module level:
   ```rust
   pub const MYSO_NEW_CONSTANT: u64 = 123;
   pub const SUI_NEW_CONSTANT: u64 = MYSO_NEW_CONSTANT;  // Backward compatibility
   ```

3. **Documentation**: Clearly document when you're using compatibility aliases

4. **Imports**: In new code, always import using the new names and avoid relying on the aliases

5. **Gradual migration**: When modifying existing code, prefer migrating to the new naming pattern while maintaining compatibility

6. **Type conversions**: Use the conversion functions in `mysocial_sdk_types_conversions` when interfacing between internal and external types

7. **Testing**: Always test both naming patterns for critical components

8. **Repository references**: When referring to repository paths or module imports in documentation, use the new naming pattern

9. **Deprecation notices**: When adding new alias functions, include deprecation notices as shown above

10. **Separation of concerns**: Consider separating the core functionality from the naming-specific elements when practical

## Challenges and Recommended Approaches

During our rebranding effort, we've identified several challenges and developed strategies to address them:

### Challenge: Circular Dependencies
- **Problem**: Renaming one module can break others that depend on it
- **Solution**: Use the alias.rs pattern to maintain compatibility during transition
- **Approach**: Create temporary compatibility layers that will be removed after full migration

### Challenge: Test Coverage Gaps
- **Problem**: Renamed modules might have tests that reference old module names
- **Solution**: Update test files simultaneously with their corresponding implementation
- **Approach**: Ensure all tests pass after each module rename before proceeding

### Challenge: Documentation Consistency
- **Problem**: Documentation may reference old module names
- **Solution**: Implement a documentation review phase after code updates
- **Approach**: Use automated search tools to find and replace outdated references

### Challenge: External API Compatibility
- **Problem**: External consumers may depend on specific module paths
- **Solution**: Consider versioned modules or clear upgrade paths
- **Approach**: Provide migration guides for external consumers

### Challenge: Package Name Conflicts
- **Problem**: Both mysocial-core and sui-core have the package name "sui-core" in Cargo.toml, causing conflicts in workspace
- **Solutions**:
  1. **Feature Flags**: Use feature flags to conditionally select dependencies
     ```toml
     [features]
     use-mysocial = []
     
     [dependencies]
     mysocial-core = { path = "../mysocial-core", optional = true }
     sui-core = { path = "../sui-core", optional = true }
     
     [dependencies.core]
     path = "../mysocial-core"
     package = "sui-core"
     features = ["use-mysocial"]
     ```
  
  2. **Phased Migration**: Temporarily exclude one of the packages from workspace during migration
  
  3. **Wrapper Packages**: Create wrapper crates that re-export functionality from both packages
     ```rust
     // In wrapper crate
     #[cfg(feature = "use-mysocial")]
     pub use mysocial_core::*;
     
     #[cfg(not(feature = "use-mysocial"))]
     pub use sui_core::*;
     ```
  
  4. **Direct Path References**: Use direct path references instead of workspace references
     ```toml
     mysocial-core = { path = "../mysocial-core" }
     # Instead of mysocial-core.workspace = true
     ```

- **Approach**: For sui-single-node-benchmark, we've started the migration by adding mysocial dependencies and keeping the package in a partially migrated state until we can resolve these conflicts

## Next Steps
1. Continue renaming remaining high-priority modules:
   - **sui-json-rpc-tests**: Update to use mysocial-core and mysocial-types for testing infrastructure
   - **sui-indexer-alt-restorer**: Update to use mysocial-core and its LiveObject alias
   - **sui-surfer**: Update to use mysocial-core for core functionality
   - **transaction-fuzzer**: Update to use mysocial-core and mysocial-types for fuzzing implementation
   - **sui-single-node-benchmark**: Update to use mysocial-core for benchmarking infrastructure
2. Expand the alias.rs module to include additional types for components like:
   - Fuzzing utilities
   - Authority verification components
   - Transaction execution components
3. Develop automated verification scripts to ensure consistent usage across the codebase
4. Update relevant documentation to reflect the new naming conventions
5. Create a migration guide for external developers who build on our platform
6. Finish verification of integration tests to ensure all components function correctly with the new naming