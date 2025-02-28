# MySocial Migration Organization

This directory contains symbolic links organized to help track the progress of the MySocial rebranding effort.

## Directory Structure

- `complete/`: Fully migrated crates that have been updated to use mysocial-core, mysocial-types, and mysocial-protocol-config
- `in-progress/`: Partially migrated crates that have started the transition but aren't fully migrated
- `needs-migration/`: Crates that have not yet been migrated
- `priorities/`: Crates organized by migration priority
  - `high/`: High priority crates to focus on next
  - `medium/`: Medium priority crates to migrate after high priority ones
  - `low/`: Lower priority crates

## Working With This Structure

This organization is designed to help you focus on what needs to be done without disrupting the actual codebase structure. All links point to the original crate locations.

The actual files remain in their original locations in the crates directory, ensuring that cargo builds and other tools work normally.

## Next Steps

1. Focus first on the high priority crates in `priorities/high/`
2. Complete the partially migrated crates in `in-progress/`
3. Run the migration status script again after making changes to update the status

This organizational structure can be regenerated at any time by running:
```
./migration_status.sh
./organize_crates.sh
```
