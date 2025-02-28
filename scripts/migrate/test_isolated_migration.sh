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
    
    # First, create a workspace-level Cargo.toml with lints to satisfy any crates that use workspace.lints
    cat > "$TEMP_DIR/Cargo.toml" << EOF
[workspace]
members = ["$CRATE"]

[workspace.lints.rust]
unsafe_code = "forbid"
EOF

    # Change to temp directory
    cd "$TEMP_DIR/$CRATE"
    
    # Create a modified Cargo.toml with direct dependencies instead of workspace ones
    # This is a more reliable approach than using sed for complex replacements
    cp Cargo.toml Cargo.toml.bak
    
    # Process the Cargo.toml file
    cat Cargo.toml.bak | perl -pe 's/(\S+)\.workspace\s*=\s*true/$1 = "0.1.0"/g' > Cargo.toml
    
    # Remove workspace lints if present
    if grep -q "lints" Cargo.toml; then
        sed -i '' '/\[lints\]/,/workspace = true/d' Cargo.toml
    fi
    
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
    
    # Add special handling for partially migrated dependencies
    if [ "$CRATE" == "sui-adapter-transactional-tests" ]; then
        local ROOT_DIR="$CURRENT_DIR"
        # Copy over the transactional test runner
        cp -r "$ROOT_DIR/crates/sui-transactional-test-runner" "$TEMP_DIR/"
        echo "Adding sui-transactional-test-runner to workspace for testing..."
        # Update the workspace Cargo.toml
        sed -i '' 's|members = \["'$CRATE'"\]|members = \["'$CRATE'", "sui-transactional-test-runner"\]|g' "$TEMP_DIR/Cargo.toml"
        # Fix paths in the test runner
        if [ -f "$TEMP_DIR/sui-transactional-test-runner/Cargo.toml" ]; then
            # Update workspace dependencies
            cd "$TEMP_DIR/sui-transactional-test-runner"
            cp Cargo.toml Cargo.toml.bak
            
            # Process the Cargo.toml file
            cat Cargo.toml.bak | perl -pe 's/(\S+)\.workspace\s*=\s*true/$1 = "0.1.0"/g' > Cargo.toml
            
            # Remove workspace lints if present
            if grep -q "lints" Cargo.toml; then
                sed -i '' '/\[lints\]/,/workspace = true/d' Cargo.toml
            fi
            
            # Fix paths
            sed -i '' 's|{ path = "../../external-crates/move/crates/move-stdlib" }|{ version = "0.1.0" }|g' Cargo.toml
            sed -i '' 's|{ path = "../../external-crates/move/crates/move-vm-runtime" }|{ version = "0.1.0" }|g' Cargo.toml
            
            # Comment out problematic dependencies
            sed -i '' 's|^simulacrum|# simulacrum|g' Cargo.toml
            sed -i '' 's|^msim|# msim|g' Cargo.toml
            sed -i '' 's|^sui-config|# sui-config|g' Cargo.toml
            sed -i '' 's|^sui-core|# sui-core|g' Cargo.toml
            sed -i '' 's|^sui-types|# sui-types|g' Cargo.toml
            sed -i '' 's|^sui-protocol-config|# sui-protocol-config|g' Cargo.toml
            
            # Add direct paths to mysocial crates
            echo 'mysocial-types = { version = "0.1.0" }' >> Cargo.toml
            echo 'mysocial-core = { version = "0.1.0" }' >> Cargo.toml
            echo 'mysocial-protocol-config = { version = "0.1.0" }' >> Cargo.toml
            
            cd "$CURRENT_DIR"
        fi
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