# Migration Scripts

This directory contains scripts to assist with the migration from sui-* to mysocial-* naming.

## Scripts

- **migrate_crate.sh**: Automates the process of migrating a crate to use mysocial dependencies
  - Updates imports in Rust files (sui_types → mysocial_types)
  - Updates dependencies in Cargo.toml (adds mysocial-* alongside existing sui-*)
  - Updates migration_report.txt to track progress
  - Uses workspace references (workspace = true) for dependencies
  - Maintains backward compatibility with both naming patterns

- **test_migration.sh**: Basic test of a migrated crate in the current workspace
  - Tests are run on the crate in isolation
  - May have issues with workspace package conflicts

- **test_isolated_migration.sh**: Creates a separate project to test a migrated crate
  - Sets up a clean temporary environment with just the migrated crate
  - Handles package name conflicts using package renaming
  - Maps workspace dependencies to specific versions
  - Supports common dependency version mapping (syn, proc-macro2, etc.)
  - Most reliable way to validate migrations without conflicts

- **migration_status.sh**: Reports on the current migration status
  - Shows counts of fully migrated, partially migrated, and not migrated crates
  - Calculates overall progress percentage
  - Lists recent migration commits
  - Suggests next migration targets based on dependency analysis

- **check_crate_status.sh**: Checks the migration status of a specific crate
  - Analyzes imports and dependencies
  - Reports whether the crate is fully migrated, partially migrated, or not migrated

## Usage

```bash
# Migrate a crate
./scripts/migrate/migrate_crate.sh sui-framework

# Test a migrated crate in the current workspace
./scripts/migrate/test_migration.sh sui-framework

# Test a migrated crate in isolation
./scripts/migrate/test_isolated_migration.sh sui-framework
```

## Migration Strategy

1. Focus on high-priority crates first
2. Migrate dependencies before dependents
3. Ensure backward compatibility with aliases
4. Test each migration to verify it doesn't break functionality
5. Update migration_report.txt after each migration
6. Document challenges and solutions in CLAUDE.md

## Common Challenges and Solutions

- **Package Name Conflicts**: Both mysocial-core and sui-core have package name "sui-core" in Cargo.toml
  - Solution in tests: Use package renaming (`package = "sui-core", path = "..."`)
  - Solution in codebase: Maintain both dependencies with clear comments
  
- **Workspace Dependencies**: Crates use .workspace = true for versions and features
  - Solution: Map common workspace dependencies to specific versions in isolated testing
  - Added support for feature flags in dependency specifications

- **Complex Dependency Chains**: Some crates depend on multiple migrated crates
  - Solution: Migrate from the bottom up (dependencies before dependents)
  - Use isolation testing to verify each crate individually

- **Feature Flags and Conditional Compilation**: Some crates use complex feature flags
  - Ongoing challenge: Improve test_isolated_migration.sh to handle these cases better

## Recently Migrated Crates

- **sui-archival**: Successfully migrated to use mysocial-types and mysocial-config
- **sui-analytics-indexer**: Updated to use mysocial-types for analytics processing 
- **sui-authority-aggregation**: Migrated to use mysocial-types types
- **sui-analytics-indexer-derive**: Verified compatibility with minimal changes

## Next Steps

- Continue improving test_isolated_migration.sh to handle more complex dependencies
- Add better support for workspace features and conditional compilation
- Create tools to verify that imports are consistently using the new naming across the codebase
- Consider automating more of the migration process