#!/bin/bash
# Test a migration on a specific crate by temporarily modifying the workspace
# This script works by testing the crate in isolation

set -e

CRATE=$1

if [ -z "$CRATE" ]; then
    echo "Usage: $0 <crate-name>"
    echo "Example: $0 sui-move-build"
    exit 1
fi

# Change to crate directory
CRATE_PATH="crates/${CRATE}"

if [ ! -d "${CRATE_PATH}" ]; then
    echo "Error: Crate directory not found at ${CRATE_PATH}"
    exit 1
fi

echo "Testing $CRATE in isolation to avoid package conflicts..."

# Run tests directly in the crate directory
cd "${CRATE_PATH}"
echo "Building crate in isolation..."
cargo build
echo "Running tests for ${CRATE}..."
cargo test

echo "Tests completed successfully!"
echo "NOTE: This test only verifies that the crate builds and passes its own unit tests."
echo "Integration with other crates will need to be verified in a full build."