#!/bin/bash
# Show the current migration status with statistics

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Extract section headers to get proper line ranges
FULLY_START=$(grep -n "FULLY MIGRATED CRATES" migration_report.txt | cut -d: -f1)
PARTIALLY_START=$(grep -n "PARTIALLY MIGRATED CRATES" migration_report.txt | cut -d: -f1)
NOT_START=$(grep -n "NOT MIGRATED CRATES" migration_report.txt | cut -d: -f1)
CHALLENGES_START=$(grep -n "Migration Challenges:" migration_report.txt | cut -d: -f1)

# Extract counts from migration_report.txt using proper line ranges
FULLY_MIGRATED=$(sed -n "${FULLY_START},${PARTIALLY_START}p" migration_report.txt | grep "^  - " | wc -l)
PARTIALLY_MIGRATED=$(sed -n "${PARTIALLY_START},${NOT_START}p" migration_report.txt | grep "^  - " | wc -l)
NOT_MIGRATED=$(sed -n "${NOT_START},${CHALLENGES_START}p" migration_report.txt | grep "^  - " | wc -l)

TOTAL=$((FULLY_MIGRATED + PARTIALLY_MIGRATED + NOT_MIGRATED))
PERCENT_FULLY_MIGRATED=$(echo "scale=1; 100 * $FULLY_MIGRATED / $TOTAL" | bc)
PERCENT_PARTIALLY_MIGRATED=$(echo "scale=1; 100 * $PARTIALLY_MIGRATED / $TOTAL" | bc)
PERCENT_NOT_MIGRATED=$(echo "scale=1; 100 * $NOT_MIGRATED / $TOTAL" | bc)
PERCENT_TOTAL_PROGRESS=$(echo "scale=1; 100 * ($FULLY_MIGRATED + $PARTIALLY_MIGRATED * 0.5) / $TOTAL" | bc)

echo "===== MYSOCIAL MIGRATION STATUS ====="
echo
echo -e "${GREEN}Fully migrated crates:${NC} $FULLY_MIGRATED ($PERCENT_FULLY_MIGRATED%)"
echo -e "${YELLOW}Partially migrated crates:${NC} $PARTIALLY_MIGRATED ($PERCENT_PARTIALLY_MIGRATED%)"
echo -e "${RED}Not migrated crates:${NC} $NOT_MIGRATED ($PERCENT_NOT_MIGRATED%)"
echo
echo -e "Total progress: ${PERCENT_TOTAL_PROGRESS}%"
echo

# Recent migrations
echo "Recent migrations:"
git log --pretty=format:"%h %ad %s" --date=short -n 5 | grep -i "migrat" | sed 's/^/  /'
echo

# Next suggested targets
echo "Suggested next targets:"
grep -A 200 "NOT MIGRATED CRATES" migration_report.txt | grep "^  - sui-" | sort | head -n 5 | while read -r line; do
    crate=${line#*- }
    if [ -f "crates/$crate/Cargo.toml" ]; then
        dep_count=$(grep -c "\.workspace" "crates/$crate/Cargo.toml" 2>/dev/null || echo "0")
        echo "  $crate ($dep_count dependencies)"
    fi
done