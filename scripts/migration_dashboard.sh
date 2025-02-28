#!/bin/bash
# migration_dashboard.sh - Dashboard script to track MySocial migration progress
#
# This script analyzes the codebase and displays a dashboard showing migration progress.
# It counts the number of migrated crates, partially migrated crates, and crates that
# still need to be migrated.

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counter variables
TOTAL_CRATES=0
FULLY_MIGRATED=0
PARTIALLY_MIGRATED=0
NOT_MIGRATED=0

# Lists of crates in each category
FULLY_MIGRATED_LIST=()
PARTIALLY_MIGRATED_LIST=()
NOT_MIGRATED_LIST=()

print_header() {
  echo -e "\n${BOLD}${CYAN}$1${NC}"
  echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}\n"
}

# Print pretty dashboard
print_dashboard() {
  local width=80
  local full_bar_width=50
  
  local fully_migrated_percent=$((FULLY_MIGRATED * 100 / TOTAL_CRATES))
  local partially_migrated_percent=$((PARTIALLY_MIGRATED * 100 / TOTAL_CRATES))
  local not_migrated_percent=$((NOT_MIGRATED * 100 / TOTAL_CRATES))
  
  local fully_migrated_bar=$((fully_migrated_percent * full_bar_width / 100))
  local partially_migrated_bar=$((partially_migrated_percent * full_bar_width / 100))
  local not_migrated_bar=$((not_migrated_percent * full_bar_width / 100))
  
  # Ensure we don't go below 1 for visible categories
  if [ $fully_migrated_bar -eq 0 ] && [ $FULLY_MIGRATED -gt 0 ]; then
    fully_migrated_bar=1
  fi
  if [ $partially_migrated_bar -eq 0 ] && [ $PARTIALLY_MIGRATED -gt 0 ]; then
    partially_migrated_bar=1
  fi
  if [ $not_migrated_bar -eq 0 ] && [ $NOT_MIGRATED -gt 0 ]; then
    not_migrated_bar=1
  fi
  
  # Adjust to ensure total is correct
  local total_bar=$((fully_migrated_bar + partially_migrated_bar + not_migrated_bar))
  if [ $total_bar -lt $full_bar_width ]; then
    not_migrated_bar=$((not_migrated_bar + (full_bar_width - total_bar)))
  elif [ $total_bar -gt $full_bar_width ]; then
    not_migrated_bar=$((not_migrated_bar - (total_bar - full_bar_width)))
  fi
  
  echo -e "${BOLD}MySocial Migration Progress Dashboard${NC}"
  echo -e "$(printf '=%.0s' $(seq 1 $width))"
  echo -e "Total Crates: ${BOLD}${TOTAL_CRATES}${NC}"
  echo
  
  # Print progress bars
  echo -e "${BOLD}Fully Migrated:${NC}     ${GREEN}$(printf '#%.0s' $(seq 1 $fully_migrated_bar))${NC}$(printf ' %.0s' $(seq 1 $((full_bar_width - fully_migrated_bar)))) ${BOLD}${FULLY_MIGRATED}${NC} (${fully_migrated_percent}%)"
  echo -e "${BOLD}Partially Migrated:${NC} ${YELLOW}$(printf '#%.0s' $(seq 1 $partially_migrated_bar))${NC}$(printf ' %.0s' $(seq 1 $((full_bar_width - partially_migrated_bar)))) ${BOLD}${PARTIALLY_MIGRATED}${NC} (${partially_migrated_percent}%)"
  echo -e "${BOLD}Not Migrated:${NC}       ${RED}$(printf '#%.0s' $(seq 1 $not_migrated_bar))${NC}$(printf ' %.0s' $(seq 1 $((full_bar_width - not_migrated_bar)))) ${BOLD}${NOT_MIGRATED}${NC} (${not_migrated_percent}%)"
  
  echo -e "$(printf '=%.0s' $(seq 1 $width))"
}

# Check if a crate is migrated
check_crate_status() {
  local crate_dir="$1"
  local crate_name="$(basename "$crate_dir")"
  
  # Skip if not a directory
  if [ ! -d "$crate_dir" ]; then
    return
  fi
  
  # Increment total crates
  TOTAL_CRATES=$((TOTAL_CRATES + 1))
  
  # Check Cargo.toml for mysocial dependencies
  local has_mysocial_dep=0
  local has_sui_dep=0
  
  if [ -f "$crate_dir/Cargo.toml" ]; then
    if grep -q "mysocial-" "$crate_dir/Cargo.toml"; then
      has_mysocial_dep=1
    fi
    if grep -q "sui-types\|sui-core\|sui-protocol-config" "$crate_dir/Cargo.toml"; then
      has_sui_dep=1
    fi
  fi
  
  # Check source files for imports
  local uses_mysocial_imports=0
  local uses_sui_imports=0
  
  # Find all Rust files
  SRC_FILES=$(find "$crate_dir" -name "*.rs" 2>/dev/null || echo "")
  
  if [ -n "$SRC_FILES" ]; then
    if grep -q "use mysocial_" <<< "$SRC_FILES"; then
      uses_mysocial_imports=1
    fi
    
    if grep -q "use sui_types::\|use sui_core::\|use sui_protocol_config::" "$crate_dir" --include="*.rs" 2>/dev/null; then
      uses_sui_imports=1
    fi
  fi
  
  # Determine migration status
  if [ $has_mysocial_dep -eq 1 ] && [ $uses_mysocial_imports -eq 1 ] && [ $uses_sui_imports -eq 0 ]; then
    FULLY_MIGRATED=$((FULLY_MIGRATED + 1))
    FULLY_MIGRATED_LIST+=("$crate_name")
  elif [ $has_mysocial_dep -eq 1 ] || [ $uses_mysocial_imports -eq 1 ]; then
    PARTIALLY_MIGRATED=$((PARTIALLY_MIGRATED + 1))
    PARTIALLY_MIGRATED_LIST+=("$crate_name")
  else
    NOT_MIGRATED=$((NOT_MIGRATED + 1))
    NOT_MIGRATED_LIST+=("$crate_name")
  fi
}

# Main logic
print_header "Analyzing MySocial Migration Status"

# Process each crate
for crate_dir in crates/sui-*/ crates/mysocial-*/; do
  check_crate_status "$crate_dir"
done

# Print dashboard
print_dashboard

# Print lists of crates in each category
if [ ${#FULLY_MIGRATED_LIST[@]} -gt 0 ]; then
  echo -e "\n${GREEN}${BOLD}Fully Migrated Crates:${NC}"
  printf "  %s\n" "${FULLY_MIGRATED_LIST[@]}" | sort
fi

if [ ${#PARTIALLY_MIGRATED_LIST[@]} -gt 0 ]; then
  echo -e "\n${YELLOW}${BOLD}Partially Migrated Crates:${NC}"
  printf "  %s\n" "${PARTIALLY_MIGRATED_LIST[@]}" | sort
fi

if [ ${#NOT_MIGRATED_LIST[@]} -gt 0 ]; then
  echo -e "\n${RED}${BOLD}Not Migrated Crates:${NC}"
  printf "  %s\n" "${NOT_MIGRATED_LIST[@]}" | sort
fi

# Print next steps
echo -e "\n${BLUE}${BOLD}Next Steps:${NC}"
echo "1. Continue migrating partially migrated crates to fully migrated status"
echo "2. Focus on high-priority crates next (check CLAUDE.md)"
echo "3. Run scripts/verify_migration.sh on each crate to validate migration quality"
echo "4. Update the migration progress in CLAUDE.md"

echo -e "\n${BOLD}Migration Report generated on $(date)${NC}"