# Migration Scripts

This directory contains scripts to assist with the migration from sui-* to mysocial-* naming.

## Scripts

- **migrate_crate.sh**: Automates the process of migrating a crate to use mysocial dependencies
  - Updates imports in Rust files
  - Updates dependencies in Cargo.toml
  - Updates migration_report.txt

- **test_migration.sh**: Tests a migrated crate in the current workspace
  - Tests are run on the crate in isolation
  - Avoids issues with workspace package conflicts

- **test_isolated_migration.sh**: Creates a separate project to test a migrated crate
  - Sets up a clean environment with just the migrated crate
  - Replaces workspace dependencies with direct path dependencies
  - Most reliable way to validate migrations

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

## Common Challenges

- Package name conflicts between mysocial-core and sui-core
- Circular dependencies during migration
- Ensuring all imports are updated correctly
- Managing test dependencies