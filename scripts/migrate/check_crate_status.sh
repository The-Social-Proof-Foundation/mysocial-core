#!/bin/bash
# Check the status of a crate for migration planning

set -e

CRATE=$1

if [ -z "$CRATE" ]; then
    echo "Usage: $0 <crate-name>"
    echo "Example: $0 sui-swarm-config"
    exit 1
fi

CRATE_PATH="crates/${CRATE}"

if [ ! -d "$CRATE_PATH" ]; then
    echo "Error: Crate directory not found at ${CRATE_PATH}"
    exit 1
fi

echo "=== Crate Analysis for $CRATE ==="

# Check Cargo.toml for dependencies
echo "Dependencies from Cargo.toml:"
DEPS=$(grep -E '(sui-|mysocial-).*workspace' "$CRATE_PATH/Cargo.toml" | sort)
echo "$DEPS"
echo 

# Count lines of Rust code
echo "Lines of Rust code:"
find "$CRATE_PATH" -name "*.rs" -exec wc -l {} \; | sort -nr

# Check for specific imports
echo
echo "Imports of sui-types:"
grep -r "use sui_types" "$CRATE_PATH/src" --include="*.rs" | wc -l

echo "Imports of sui-config:"
grep -r "use sui_config" "$CRATE_PATH/src" --include="*.rs" | wc -l

echo "Imports of sui-protocol-config:"
grep -r "use sui_protocol_config" "$CRATE_PATH/src" --include="*.rs" | wc -l

echo 
echo "Migration complexity assessment:"
DEPS_COUNT=$(echo "$DEPS" | wc -l)
FILES_COUNT=$(find "$CRATE_PATH/src" -name "*.rs" | wc -l)

if [ "$DEPS_COUNT" -gt 10 ]; then
    COMPLEXITY="High"
elif [ "$DEPS_COUNT" -gt 5 ]; then
    COMPLEXITY="Medium"
else
    COMPLEXITY="Low"
fi

echo "- Dependencies: $DEPS_COUNT ($COMPLEXITY complexity)"
echo "- Files: $FILES_COUNT"
echo 
echo "Recommendation:"
if [ "$COMPLEXITY" = "Low" ]; then
    echo "This crate has low complexity and should be relatively easy to migrate."
elif [ "$COMPLEXITY" = "Medium" ]; then
    echo "This crate has medium complexity. Plan for a careful migration."
else
    echo "This crate has high complexity. Consider breaking the migration into stages."
fi