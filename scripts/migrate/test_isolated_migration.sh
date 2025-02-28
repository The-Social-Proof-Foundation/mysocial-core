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
    
    # Create a modified Cargo.toml with direct dependencies instead of workspace ones
    # This is a more reliable approach than using sed for complex replacements
    cp Cargo.toml Cargo.toml.bak
    
    # Process the Cargo.toml file
    cat Cargo.toml.bak | perl -pe 's/(\S+)\.workspace\s*=\s*true/$1 = "0.1.0"/g' > Cargo.toml
    
    # Special handling for mysocial-types
    if grep -q "mysocial-types" Cargo.toml; then
        sed -i '' 's|{ path = "../mysocial-types" }|{ path = "../../../crates/mysocial-types" }|g' Cargo.toml
    fi
    
    if grep -q "mysocial-core" Cargo.toml; then
        sed -i '' 's|{ path = "../mysocial-core" }|{ path = "../../../crates/mysocial-core" }|g' Cargo.toml
    fi
    
    if grep -q "mysocial-config" Cargo.toml; then
        sed -i '' 's|{ path = "../mysocial-config" }|{ path = "../../../crates/mysocial-config" }|g' Cargo.toml
    fi
    
    if grep -q "mysocial-protocol-config" Cargo.toml; then
        sed -i '' 's|{ path = "../mysocial-protocol-config" }|{ path = "../../../crates/mysocial-protocol-config" }|g' Cargo.toml
    fi
    
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