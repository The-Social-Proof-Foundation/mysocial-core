#!/bin/bash
# Script to help with migration of a crate to use mysocial dependencies

set -e

CRATE=$1

if [ -z "$CRATE" ]; then
    echo "Usage: $0 <crate-name>"
    echo "Example: $0 sui-move-build"
    exit 1
fi

CRATE_PATH="crates/${CRATE}"

if [ ! -d "${CRATE_PATH}" ]; then
    echo "Error: Crate directory not found at ${CRATE_PATH}"
    exit 1
fi

echo "Starting migration of ${CRATE}..."

# Function to update Cargo.toml dependencies
update_cargo_toml() {
    echo "Updating Cargo.toml dependencies..."
    
    # Add mysocial-types with workspace reference
    if grep -q "sui-types" "${CRATE_PATH}/Cargo.toml"; then
        # Check if mysocial-types is already added
        if ! grep -q "mysocial-types" "${CRATE_PATH}/Cargo.toml"; then
            sed -i '' '/sui-types/i\
mysocial-types = { workspace = true }\
' "${CRATE_PATH}/Cargo.toml"
            # Add comment to existing sui-types
            sed -i '' '/sui-types/s/$/  # Keep for backward compatibility/' "${CRATE_PATH}/Cargo.toml"
        fi
    fi
    
    # Add mysocial-protocol-config with workspace reference
    if grep -q "sui-protocol-config" "${CRATE_PATH}/Cargo.toml"; then
        # Check if mysocial-protocol-config is already added
        if ! grep -q "mysocial-protocol-config" "${CRATE_PATH}/Cargo.toml"; then
            sed -i '' '/sui-protocol-config/i\
mysocial-protocol-config = { workspace = true }\
' "${CRATE_PATH}/Cargo.toml"
            # Add comment to existing sui-protocol-config
            sed -i '' '/sui-protocol-config/s/$/  # Keep for backward compatibility/' "${CRATE_PATH}/Cargo.toml"
        fi
    fi
    
    # Add mysocial-core with workspace reference
    if grep -q "sui-core" "${CRATE_PATH}/Cargo.toml"; then
        # Check if mysocial-core is already added
        if ! grep -q "mysocial-core" "${CRATE_PATH}/Cargo.toml"; then
            sed -i '' '/sui-core/i\
mysocial-core = { workspace = true }\
' "${CRATE_PATH}/Cargo.toml"
            # Add comment to existing sui-core (if not commented out)
            sed -i '' '/sui-core/s/$/  # Keep for backward compatibility/' "${CRATE_PATH}/Cargo.toml"
        fi
    fi
    
    # Add mysocial-config with workspace reference
    if grep -q "sui-config" "${CRATE_PATH}/Cargo.toml"; then
        # Check if mysocial-config is already added
        if ! grep -q "mysocial-config" "${CRATE_PATH}/Cargo.toml"; then
            sed -i '' '/sui-config/i\
mysocial-config = { workspace = true }\
' "${CRATE_PATH}/Cargo.toml"
            # Add comment to existing sui-config
            sed -i '' '/sui-config/s/$/  # Keep for backward compatibility/' "${CRATE_PATH}/Cargo.toml"
        fi
    fi
}

# Function to update imports in Rust files
update_imports() {
    echo "Updating imports in Rust files..."
    
    find "${CRATE_PATH}/src" -name "*.rs" -type f | while read -r file; do
        # Update sui-types to mysocial-types
        if grep -q "use sui_types" "${file}"; then
            sed -i '' 's/use sui_types/use mysocial_types/g' "${file}"
        fi
        
        # Update sui-protocol-config to mysocial-protocol-config
        if grep -q "use sui_protocol_config" "${file}"; then
            sed -i '' 's/use sui_protocol_config/use mysocial_protocol_config/g' "${file}"
        fi
        
        # Update sui-core to mysocial-core
        if grep -q "use sui_core" "${file}"; then
            sed -i '' 's/use sui_core/use mysocial_core/g' "${file}"
        fi
        
        # Update sui-config to mysocial-config
        if grep -q "use sui_config" "${file}"; then
            sed -i '' 's/use sui_config/use mysocial_config/g' "${file}"
        fi
        
        # Look for SUI_* constants and update to MYSO_* with aliases
        if grep -q "SUI_FRAMEWORK_ADDRESS" "${file}"; then
            sed -i '' 's/SUI_FRAMEWORK_ADDRESS/MYSO_FRAMEWORK_ADDRESS as SUI_FRAMEWORK_ADDRESS/g' "${file}"
        fi
        
        if grep -q "SUI_SYSTEM_ADDRESS" "${file}"; then
            sed -i '' 's/SUI_SYSTEM_ADDRESS/MYSO_SYSTEM_ADDRESS as SUI_SYSTEM_ADDRESS/g' "${file}"
        fi
    done
}

# Update dependencies in Cargo.toml
update_cargo_toml

# Update imports in Rust files
update_imports

echo "Migration completed for ${CRATE}. Now you can run tests using:"
echo "./scripts/test_migration.sh ${CRATE}"

# Update migration_report.txt
if grep -q "${CRATE}" migration_report.txt; then
    # Move from NOT MIGRATED to PARTIALLY MIGRATED
    if grep -q "^  - ${CRATE}$" migration_report.txt; then
        echo "Updating migration_report.txt to mark ${CRATE} as partially migrated"
        sed -i '' "/^  - ${CRATE}$/d" migration_report.txt
        sed -i '' "/^PARTIALLY MIGRATED CRATES/a\\
\  - ${CRATE}" migration_report.txt
    fi
fi

echo "Remember to commit your changes when you're satisfied with the migration."