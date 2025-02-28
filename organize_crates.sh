#\!/bin/bash

# Create organizational structure for migrated crates
rm -rf crates/migrated
mkdir -p crates/migrated/complete
mkdir -p crates/migrated/in-progress
mkdir -p crates/migrated/needs-migration

# Read the migration report directly from the report file
REPORT_FILE="migration_report.txt"
if [ \! -f "$REPORT_FILE" ]; then
  echo "Error: Migration report file not found. Run ./migration_status.sh first."
  exit 1
fi

# Extract categories from the report
FULLY_START=$(grep -n "^FULLY MIGRATED CRATES" "$REPORT_FILE" | cut -d ':' -f 1)
PARTIALLY_START=$(grep -n "^PARTIALLY MIGRATED CRATES" "$REPORT_FILE" | cut -d ':' -f 1)
NOT_START=$(grep -n "^NOT MIGRATED CRATES" "$REPORT_FILE" | cut -d ':' -f 1)
NEXT_STEPS_START=$(grep -n "^Next steps:" "$REPORT_FILE" | cut -d ':' -f 1)

FULLY_END=$((PARTIALLY_START - 2))
PARTIALLY_END=$((NOT_START - 2))
NOT_END=$((NEXT_STEPS_START - 2))

FULLY_MIGRATED=$(sed -n "$((FULLY_START + 1)),$FULLY_END p" "$REPORT_FILE" | grep "^ " | awk '{print $2}')
PARTIALLY_MIGRATED=$(sed -n "$((PARTIALLY_START + 1)),$PARTIALLY_END p" "$REPORT_FILE" | grep "^ " | awk '{print $2}')
NOT_MIGRATED=$(sed -n "$((NOT_START + 1)),$NOT_END p" "$REPORT_FILE" | grep "^ " | awk '{print $2}')

# Create priority JSON file
cat > migration_priorities.json << 'JSONEOF'
{
  "high_priority": [
    "sui-indexer-alt-restorer",
    "sui-json-rpc-tests",
    "sui-surfer",
    "transaction-fuzzer",
    "sui-single-node-benchmark",
    "sui-core"
  ],
  "medium_priority": [
    "sui-json-rpc",
    "sui-node",
    "sui-tool",
    "sui-network",
    "sui-faucet",
    "sui-genesis-builder"
  ],
  "low_priority": [
    "sui-proxy",
    "sui-rosetta",
    "sui-tls"
  ]
}
JSONEOF

echo "Creating symbolic links for fully migrated crates..."
for crate in $FULLY_MIGRATED; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/complete/$crate"
    echo "  - $crate"
  fi
done

echo "Creating symbolic links for partially migrated crates..."
for crate in $PARTIALLY_MIGRATED; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/in-progress/$crate"
    echo "  - $crate"
  fi
done

echo "Creating symbolic links for non-migrated crates..."
for crate in $NOT_MIGRATED; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/needs-migration/$crate"
  fi
done

# Create priority lists
mkdir -p crates/migrated/priorities/high
mkdir -p crates/migrated/priorities/medium
mkdir -p crates/migrated/priorities/low

# Parse high priority crates from the JSON (simple approach without jq)
HIGH_PRIORITY=$(grep -o '"high_priority": \[[^]]*\]' migration_priorities.json | grep -o '"[^"]*"' | sed 's/"//g')
MEDIUM_PRIORITY=$(grep -o '"medium_priority": \[[^]]*\]' migration_priorities.json | grep -o '"[^"]*"' | sed 's/"//g')
LOW_PRIORITY=$(grep -o '"low_priority": \[[^]]*\]' migration_priorities.json | grep -o '"[^"]*"' | sed 's/"//g')

echo "Setting up priority symbolic links..."
echo "High priority crates:"
for crate in $HIGH_PRIORITY; do
  # Only create links if the crate exists
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/priorities/high/$crate"
    echo "  - $crate"
  fi
done

echo "Medium priority crates:"
for crate in $MEDIUM_PRIORITY; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/priorities/medium/$crate"
    echo "  - $crate"
  fi
done

echo "Low priority crates:"
for crate in $LOW_PRIORITY; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/priorities/low/$crate"
    echo "  - $crate"
  fi
done

# Create a README.md file explaining the structure
cat > crates/migrated/README.md << 'MDEOF'
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
MDEOF

echo "Organizational structure has been created:"
echo "- crates/migrated/complete/ - Fully migrated crates"
echo "- crates/migrated/in-progress/ - Partially migrated crates" 
echo "- crates/migrated/needs-migration/ - Crates that need migration"
echo "- crates/migrated/priorities/ - Priority-based organization"
echo ""
echo "You can now easily see what crates are in each stage of migration"
echo "and focus on high priority crates for your next steps."
echo ""
echo "See crates/migrated/README.md for more information."
