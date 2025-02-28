#!/bin/bash
# Run isolated tests for all partially migrated crates

set -e

# Get the list of partially migrated crates from migration_report.txt
PARTIALLY_MIGRATED=$(grep -A 50 "PARTIALLY MIGRATED CRATES" migration_report.txt | grep "^  - " | cut -d' ' -f4)

echo "=== Testing All Partially Migrated Crates ==="
echo "Crates to test:"
echo "$PARTIALLY_MIGRATED"
echo

FAILED_CRATES=""
SUCCESSFUL_CRATES=""

for CRATE in $PARTIALLY_MIGRATED; do
    echo "Testing $CRATE..."
    if ./scripts/migrate/test_isolated_migration.sh "$CRATE" > /tmp/test_output_$CRATE.log 2>&1; then
        echo "✅ $CRATE passed isolated testing"
        SUCCESSFUL_CRATES="$SUCCESSFUL_CRATES $CRATE"
    else
        echo "❌ $CRATE failed isolated testing"
        FAILED_CRATES="$FAILED_CRATES $CRATE"
        echo "See log at /tmp/test_output_$CRATE.log"
    fi
    echo
done

echo "=== Test Summary ==="
echo "Successfully tested crates:$SUCCESSFUL_CRATES"

if [ -n "$FAILED_CRATES" ]; then
    echo "Failed crates:$FAILED_CRATES"
    echo "See logs in /tmp/test_output_*.log"
    exit 1
else
    echo "All partially migrated crates passed isolated testing!"
fi