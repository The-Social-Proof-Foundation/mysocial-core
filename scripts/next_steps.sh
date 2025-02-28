#!/bin/bash
# next_steps.sh - Script to suggest the next migration steps
#
# This script analyzes migration progress and recommends next actions.

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
  echo -e "\n${BOLD}${CYAN}$1${NC}"
  echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}\n"
}

# Make sure our organization is up to date
if [ ! -d "crates/migrated" ]; then
  echo "Running organize_crates.sh to set up directory structure..."
  ./scripts/organize_crates.sh > /dev/null
fi

print_header "MySocial Migration - Next Steps"

# Check our progress
complete_count=$(ls -1 crates/migrated/complete/ 2>/dev/null | wc -l)
in_progress_count=$(ls -1 crates/migrated/in-progress/ 2>/dev/null | wc -l)
needs_migration_count=$(ls -1 crates/migrated/needs-migration/ 2>/dev/null | wc -l)
priority_count=$(ls -1 crates/migrated/priorities/ | grep -v "high\|medium\|low" 2>/dev/null | wc -l)

echo -e "${GREEN}Completed:${NC} $complete_count crates"
echo -e "${YELLOW}In Progress:${NC} $in_progress_count crates"
echo -e "${RED}Needs Migration:${NC} $needs_migration_count crates"
echo -e "${BOLD}High Priority:${NC} $priority_count crates"

# Get the top 3 priority crates by checking dependency counts
print_header "Top Priority Crates"

# Use grep to find the top priority crates directly
echo "Finding top priority crates..."
for crate_link in crates/migrated/priorities/sui-*; do
  if [ ! -L "$crate_link" ]; then
    continue
  fi
  
  crate_name=$(basename "$crate_link")
  
  # Find dependency count from Cargo.toml references
  package_name="sui-${crate_name#sui-}"
  dep_count=$(grep -l "$package_name.*workspace = true" crates/*/Cargo.toml 2>/dev/null | wc -l)
  
  # Print name and score for later sorting
  echo "$crate_name $dep_count"
done > /tmp/priority_crates.txt

# Sort and print top priorities
for crate_name in $(sort -k2 -nr /tmp/priority_crates.txt | head -5 | awk '{print $1}'); do
  # Get dependency count
  dep_count=$(grep "^$crate_name " /tmp/priority_crates.txt | awk '{print $2}')
  
  # Check if it uses sui-types or sui-core directly
  uses_core_or_types="No"
  if grep -q "use sui_types::\|use sui_core::" "crates/$crate_name" --include="*.rs" 2>/dev/null; then
    uses_core_or_types="Yes"
  fi
  
  # Check actual file size
  file_count=$(find "crates/$crate_name" -name "*.rs" 2>/dev/null | wc -l)
  
  echo -e "${BOLD}$crate_name${NC}"
  echo "  Dependencies: $dep_count"
  echo "  Rust Files: $file_count"
  echo "  Uses sui_types/sui_core directly: $uses_core_or_types"
  
  if [ "$uses_core_or_types" = "Yes" ]; then
    # Count occurrences
    sui_types_count=$(grep -r "use sui_types::" "crates/$crate_name" --include="*.rs" 2>/dev/null | wc -l)
    sui_core_count=$(grep -r "use sui_core::" "crates/$crate_name" --include="*.rs" 2>/dev/null | wc -l)
    echo "  sui_types occurrences: $sui_types_count"
    echo "  sui_core occurrences: $sui_core_count"
  fi
  
  echo
done

# Clean up temporary file
rm -f /tmp/priority_crates.txt

# Give actionable advice
print_header "Recommended Actions"

echo "1. ${BOLD}Choose one of the high priority crates above${NC} to migrate next"
echo "2. For your chosen crate:"
echo "   a. Update Cargo.toml to add mysocial-* dependencies"
echo "   b. Update imports to use mysocial_* instead of sui_*"
echo "   c. Verify with scripts/verify_migration.sh <crate-name>"
echo "3. After migration, run scripts/organize_crates.sh to update tracking"
echo "4. Update CLAUDE.md with the progress"

echo
echo -e "To start working on a specific crate, run:\n"
echo -e "  ${GREEN}cd crates/<crate-name>${NC}"
echo -e "  ${GREEN}scripts/verify_migration.sh <crate-name>${NC} (to check current status)"
echo