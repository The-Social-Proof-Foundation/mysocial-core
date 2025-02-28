#!/bin/bash
# Test a migration on a specific crate by temporarily modifying the workspace

set -e

CRATE=$1

if [ -z "$CRATE" ]; then
    echo "Usage: $0 <crate-name>"
    echo "Example: $0 sui-move-build"
    exit 1
fi

ORIGINAL_WORKSPACE_FILE="Cargo.toml"
BACKUP_WORKSPACE_FILE="${ORIGINAL_WORKSPACE_FILE}.bak"

# Create a backup of the workspace file
cp "${ORIGINAL_WORKSPACE_FILE}" "${BACKUP_WORKSPACE_FILE}"

cleanup() {
    echo "Restoring original workspace configuration..."
    mv "${BACKUP_WORKSPACE_FILE}" "${ORIGINAL_WORKSPACE_FILE}"
    echo "Done."
}

# Set up cleanup on exit
trap cleanup EXIT

echo "Temporarily modifying workspace to test $CRATE migration..."

# Comment out the sui-core entry to avoid package name conflicts
sed -i '' '/crates\/sui-core/s/^/#/' "${ORIGINAL_WORKSPACE_FILE}"

# Run the tests for the specified crate
echo "Running tests for $CRATE..."
cargo test -p "${CRATE}"

echo "Tests completed. Restoring original workspace configuration."