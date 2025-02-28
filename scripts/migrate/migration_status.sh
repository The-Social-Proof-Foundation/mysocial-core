#!/bin/bash
# Show the current migration status with statistics

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Extract counts from migration_report.txt
FULLY_MIGRATED=$(grep -A 100 "FULLY MIGRATED CRATES" migration_report.txt | grep "^  - " | wc -l)
PARTIALLY_MIGRATED=$(grep -A 100 "PARTIALLY MIGRATED CRATES" migration_report.txt | grep "^  - " | wc -l)
NOT_MIGRATED=$(grep -A 200 "NOT MIGRATED CRATES" migration_report.txt | grep "^  - " | wc -l)

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
high_priority_not_migrated=$(grep -A 200 "NOT MIGRATED CRATES" migration_report.txt | grep "^  - sui-" | sort | head -n 5)
for crate in $high_priority_not_migrated; do
    dep_count=$(grep -c "\.workspace" crates/$crate/Cargo.toml 2>/dev/null || echo "0")
    echo "  $crate ($dep_count dependencies)"
done