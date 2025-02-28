# High Priority Migration Tasks

These crates have been identified as the highest priority for the MySocial rebranding effort. They should be migrated next.

## Current Status

Each of these crates is in a different stage of migration:

- ✅ **sui-indexer-alt-restorer**: Successfully migrated to use mysocial-core's LiveObject alias
- ✅ **sui-json-rpc-tests**: Successfully migrated to use mysocial-core, mysocial-types, and mysocial-protocol-config
- ✅ **sui-single-node-benchmark**: Successfully migrated to use mysocial-core and mysocial-types for benchmarking
- **sui-surfer**: Needs migration to use mysocial-core for core functionality
- **transaction-fuzzer**: Needs migration to use mysocial-core and mysocial-types for fuzzing implementation
- **sui-core**: Special case - this is being replaced by mysocial-core but needs to be maintained for compatibility

## Migration Steps

For each crate:

1. Update Cargo.toml to add mysocial-core, mysocial-types, and mysocial-protocol-config dependencies alongside the original sui-* dependencies
2. Update imports to use mysocial_* instead of sui_*
3. Add appropriate "# Keep for backward compatibility" comments for the original dependencies
4. Verify the imports are correct using import verification scripts
5. Update documentation and tests to reflect the new naming

## Migration Order Recommendation

1. **transaction-fuzzer** - Important for security validation
2. **sui-surfer** - Useful utility but less critical path
3. **sui-core** - Continue gradually phasing out in favor of mysocial-core

After these are complete, proceed to the crates in the medium priority directory.
