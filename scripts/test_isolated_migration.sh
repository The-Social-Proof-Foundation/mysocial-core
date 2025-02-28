#!/bin/bash
# Test a migration by creating a separate project for testing the migrated crate in isolation

set -e

CRATE=$1

if [ -z "$CRATE" ]; then
    echo "Usage: $0 <crate-name>"
    echo "Example: $0 sui-move-build"
    exit 1
fi

# Create a temporary directory for isolated testing
TEMP_DIR=$(mktemp -d)
echo "Creating isolated test environment in $TEMP_DIR"

# Function to clean up temporary directory
cleanup() {
    echo "Cleaning up temporary test environment..."
    rm -rf "$TEMP_DIR"
    echo "Done."
}

# Register cleanup function to be called on script exit
trap cleanup EXIT

# Copy the crate to the temporary directory
CRATE_PATH="crates/${CRATE}"
cp -r "$CRATE_PATH" "$TEMP_DIR/"

# Create a simple Cargo.toml for the temp project
cat > "$TEMP_DIR/Cargo.toml" << EOF
[workspace]
members = ["$CRATE"]
EOF

# Function to replace workspace dependencies with direct dependencies in crate's Cargo.toml
replace_workspace_deps() {
    # Save current directory
    local CURRENT_DIR=$(pwd)
    
    # Change to temp directory
    cd "$TEMP_DIR/$CRATE"
    
    # Use sed to replace workspace dependencies with direct path dependencies
    sed -i '' 's/\.workspace = true/{ path = "..\/..\/..\/crates\/&" }/g' Cargo.toml
    
    # Return to original directory
    cd "$CURRENT_DIR"
}

# Call the function to replace workspace dependencies
replace_workspace_deps

# Run cargo check in the temporary directory
echo "Running cargo check in isolated environment..."
(cd "$TEMP_DIR" && cargo check)

echo "Isolated test for $CRATE completed successfully!"
echo "NOTE: This test only verifies that the crate builds in isolation."
echo "Integration with other crates will need to be verified in a full build."