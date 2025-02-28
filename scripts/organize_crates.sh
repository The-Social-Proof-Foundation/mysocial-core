#!/bin/bash
# organize_crates.sh - Script to organize crates by migration status
#
# This script creates a directory structure in crates/migrated/ to help track
# migration progress and prioritize next steps.

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
  echo -e "\n${BOLD}${CYAN}$1${NC}"
  echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}\n"
}

# Create directory structure
mkdir -p crates/migrated/{complete,in-progress,needs-migration,priorities}

# Clear existing symlinks
find crates/migrated -type l -delete

print_header "Organizing MySocial Crates by Migration Status"

# Function to check if a crate is fully migrated
is_fully_migrated() {
  local crate_dir="$1"
  
  # Check for mysocial dependencies
  if ! grep -q "mysocial-" "$crate_dir/Cargo.toml" 2>/dev/null; then
    return 1
  fi
  
  # Check for no sui_types or sui_core imports
  if grep -q "use sui_types::\|use sui_core::" "$crate_dir" --include="*.rs" 2>/dev/null; then
    return 1
  fi
  
  # If we get here, it's fully migrated
  return 0
}

# Function to check if a crate is partially migrated
is_partially_migrated() {
  local crate_dir="$1"
  
  # Check for mysocial dependencies or imports
  if grep -q "mysocial-" "$crate_dir/Cargo.toml" 2>/dev/null; then
    return 0
  fi
  
  if grep -q "use mysocial_" "$crate_dir" --include="*.rs" 2>/dev/null; then
    return 0
  fi
  
  # If we get here, it's not migrated at all
  return 1
}

# Function to get the priority score (higher = higher priority)
get_priority_score() {
  local crate_name="$1"
  local package_name="sui-${crate_name#sui-}"  # Ensure we're looking for the package name
  
  # Check for references to this crate in other Cargo.toml files
  local count=$(grep -l "$package_name.*workspace = true" crates/*/Cargo.toml 2>/dev/null | wc -l)
  local direct_count=$(grep -l "\"$package_name\"" crates/*/Cargo.toml 2>/dev/null | wc -l)
  
  # Total count
  echo $((count + direct_count))
}

# Track counts
fully_migrated=0
partially_migrated=0
needs_migration=0
high_priority=0

echo "Looking for crates..."

# Process each crate
for crate_dir in crates/sui-*/ crates/mysocial-*/; do
  # Skip if not a directory
  if [ ! -d "$crate_dir" ]; then
    continue
  fi
  
  crate_name=$(basename "$crate_dir")
  
  # Skip if it's the migrated directory itself
  if [ "$crate_name" = "migrated" ]; then
    continue
  fi
  
  if is_fully_migrated "$crate_dir"; then
    # Fully migrated crates
    ln -sf "../$crate_name" "crates/migrated/complete/"
    fully_migrated=$((fully_migrated + 1))
    echo -e "${GREEN}✓ $crate_name${NC} - Fully migrated"
  elif is_partially_migrated "$crate_dir"; then
    # Partially migrated crates
    ln -sf "../$crate_name" "crates/migrated/in-progress/"
    partially_migrated=$((partially_migrated + 1))
    echo -e "${YELLOW}⚠ $crate_name${NC} - Partially migrated"
  else
    # Not migrated crates
    ln -sf "../$crate_name" "crates/migrated/needs-migration/"
    needs_migration=$((needs_migration + 1))
    
    # Check if high priority
    priority=$(get_priority_score "$crate_name")
    if [ "$priority" -gt 5 ]; then
      ln -sf "../$crate_name" "crates/migrated/priorities/"
      high_priority=$((high_priority + 1))
      echo -e "${RED}! $crate_name${NC} - Needs migration (priority: $priority)"
    else
      echo -e "${RED}✗ $crate_name${NC} - Needs migration"
    fi
  fi
done

echo
echo -e "${GREEN}Fully migrated:${NC} $fully_migrated crates"
echo -e "${YELLOW}Partially migrated:${NC} $partially_migrated crates"
echo -e "${RED}Needs migration:${NC} $needs_migration crates"
echo -e "${BOLD}High priority:${NC} $high_priority crates"

echo
echo "Directory structure created at crates/migrated/"
echo "- complete/: Fully migrated crates"
echo "- in-progress/: Partially migrated crates"
echo "- needs-migration/: Crates that need migration"
echo "- priorities/: High priority crates to migrate next"

echo
echo -e "${BOLD}Next steps:${NC}"
echo "1. Run 'ls -l crates/migrated/priorities/' to see high priority crates"
echo "2. Choose a crate from the priorities folder to work on next"
echo "3. After migrating, run this script again to update the directory structure"