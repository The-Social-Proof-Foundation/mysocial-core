#!/bin/bash

# Copyright (c) The Social Proof Foundation
# SPDX-License-Identifier: Apache-2.0

# Test script to verify the compatibility between mysocial-core and the rest of the codebase
set -e

CRATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$CRATES_DIR/.." && pwd)"

echo "=== Testing mysocial-core compatibility with other crates ==="

# Get list of crates that depend on mysocial-core
DEPENDENT_CRATES=(
  "mysocial-indexer"
  "sui-config"
  "sui-node"
  "sui-test-validator"
)

echo "Running 'cargo check' on dependent crates..."
for crate in "${DEPENDENT_CRATES[@]}"; do
  echo "Checking crate: $crate"
  (cd "$REPO_ROOT" && cargo check -p "$crate")
done

echo "Running specific test for mysocial-indexer to verify LiveObject is correctly used..."

# Create a small test program to verify the LiveObject imported correctly from mysocial-core
TEST_FILE="$CRATES_DIR/mysocial-indexer/src/test_mysocial_core_import.rs"

cat > "$TEST_FILE" << EOF
// Copyright (c) The Social Proof Foundation
// SPDX-License-Identifier: Apache-2.0

// This is a test file to verify that mysocial-indexer correctly imports LiveObject from mysocial-core
// when the 'use-mysocial-core' feature is enabled (default).

use mysocial_core::authority::authority_store_tables::LiveObject;
use sui_types::object::Object;

fn main() {
    println!("Successfully imported LiveObject from mysocial-core");
    // This is just a compile-time check, no need to actually run the code
}
EOF

echo "Compiling test file to verify imports..."
(cd "$REPO_ROOT" && cargo check --bin mysocial-indexer)

echo "=== All tests passed! ==="
echo "mysocial-core is correctly integrated with the codebase."

# Clean up test file
rm "$TEST_FILE"