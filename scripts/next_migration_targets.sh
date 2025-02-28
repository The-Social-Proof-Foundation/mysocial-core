#!/bin/bash
# next_migration_targets.sh - Script to identify the next best migration targets
# 
# This script analyzes remaining crates and prioritizes them by:
# 1. Analyzing dependencies
# 2. Checking complexity
# 3. Creating a priority list based on impact and complexity

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Output file
OUTPUT_FILE="migration_priorities.json"

# Helper functions
print_header() {
  echo -e "\n${BOLD}${CYAN}$1${NC}"
  echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}\n"
}

# Lists to track our findings
ALREADY_MIGRATED=()
HIGH_PRIORITY=()
MEDIUM_PRIORITY=()
LOW_PRIORITY=()

# Check if a crate uses core/types directly
uses_core_or_types() {
  local crate_dir="$1"
  
  # Search for sui_core imports
  if grep -q "use sui_core::" "$crate_dir" --include="*.rs" 2>/dev/null; then
    echo "true"
    return
  fi
  
  # Search for sui_types imports
  if grep -q "use sui_types::" "$crate_dir" --include="*.rs" 2>/dev/null; then
    echo "true" 
    return
  fi
  
  # Search for dependency on sui-core or sui-types
  if grep -q "sui-core.*workspace = true" "$crate_dir/Cargo.toml" 2>/dev/null; then
    echo "true"
    return
  fi
  
  if grep -q "sui-types.*workspace = true" "$crate_dir/Cargo.toml" 2>/dev/null; then
    echo "true"
    return
  fi
  
  echo "false"
}

# Check dependency complexity - how many other crates depend on this one
check_dependency_complexity() {
  local crate_name="$1"
  local package_name="sui-${crate_name#sui-}"  # Ensure we're looking for the package name
  
  # Check for references to this crate in other Cargo.toml files
  local count=$(grep -l "$package_name.*workspace = true" crates/*/Cargo.toml 2>/dev/null | wc -l)
  local direct_count=$(grep -l "\"$package_name\"" crates/*/Cargo.toml 2>/dev/null | wc -l)
  
  # Total count
  echo $((count + direct_count))
}

# Check size complexity - rough estimate based on lines of code
check_size_complexity() {
  local crate_dir="$1"
  local loc=$(find "$crate_dir" -name "*.rs" -exec cat {} \; 2>/dev/null | wc -l)
  echo "$loc"
}

# Check if already partially migrated
is_partially_migrated() {
  local crate_dir="$1"
  
  if grep -q "mysocial-" "$crate_dir/Cargo.toml" 2>/dev/null; then
    echo "true"
    return
  fi
  
  if grep -q "use mysocial_" "$crate_dir" --include="*.rs" 2>/dev/null; then
    echo "true"
    return
  fi
  
  echo "false"
}

# Get all sui-prefixed crates that haven't been fully migrated
get_remaining_crates() {
  local migrated_count=0
  local remaining_count=0
  
  for crate_dir in crates/sui-*/; do
    local crate_name=$(basename "$crate_dir")
    
    # Skip some directories that we know are already migrated or shouldn't be migrated
    if [[ " ${ALREADY_MIGRATED[@]} " =~ " ${crate_name} " ]]; then
      continue
    fi
    
    if [ "$(is_partially_migrated "$crate_dir")" == "true" ]; then
      # Check if it still has sui_types or sui_core imports
      if [ "$(uses_core_or_types "$crate_dir")" == "true" ]; then
        # Add to high priority if partially migrated but still has old imports
        local deps=$(check_dependency_complexity "$crate_name")
        local size=$(check_size_complexity "$crate_dir")
        HIGH_PRIORITY+=("$crate_name|$deps|$size|partial")
      else
        # Already migrated, just track it
        ALREADY_MIGRATED+=("$crate_name")
        migrated_count=$((migrated_count + 1))
      fi
    else
      # Not migrated yet, check if it uses core or types directly
      if [ "$(uses_core_or_types "$crate_dir")" == "true" ]; then
        local deps=$(check_dependency_complexity "$crate_name")
        local size=$(check_size_complexity "$crate_dir")
        
        # Categorize by complexity and impact
        if [ $deps -gt 5 ]; then
          HIGH_PRIORITY+=("$crate_name|$deps|$size|none")
        elif [ $deps -gt 2 ]; then
          MEDIUM_PRIORITY+=("$crate_name|$deps|$size|none")
        else
          LOW_PRIORITY+=("$crate_name|$deps|$size|none")
        fi
      else
        # Low priority if doesn't use core/types directly
        local deps=$(check_dependency_complexity "$crate_name")
        local size=$(check_size_complexity "$crate_dir")
        LOW_PRIORITY+=("$crate_name|$deps|$size|none")
      fi
      
      remaining_count=$((remaining_count + 1))
    fi
  done
  
  echo "Found $migrated_count migrated crates and $remaining_count remaining crates."
}

# Main function
main() {
  print_header "Identifying Next Migration Targets"
  
  # Pre-populate already migrated list
  ALREADY_MIGRATED+=("sui-json-rpc-tests")
  ALREADY_MIGRATED+=("sui-indexer-alt-restorer")
  ALREADY_MIGRATED+=("sui-single-node-benchmark")
  ALREADY_MIGRATED+=("sui-surfer")
  ALREADY_MIGRATED+=("transaction-fuzzer")
  
  # Get remaining crates
  get_remaining_crates
  
  # Sort priority lists by dependency count (descending)
  IFS=$'\n' 
  HIGH_PRIORITY=($(sort -t'|' -k2 -nr <<<"${HIGH_PRIORITY[*]}"))
  MEDIUM_PRIORITY=($(sort -t'|' -k2 -nr <<<"${MEDIUM_PRIORITY[*]}"))
  LOW_PRIORITY=($(sort -t'|' -k2 -nr <<<"${LOW_PRIORITY[*]}"))
  unset IFS
  
  # Print priority lists
  echo -e "\n${BOLD}${GREEN}High Priority Targets (uses core/types directly and highly depended on):${NC}"
  printf "%-35s %-15s %-15s %-15s\n" "Crate" "Dependencies" "Size (LoC)" "Migration Status"
  printf "%-35s %-15s %-15s %-15s\n" "$(printf '=%.0s' {1..35})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})"
  
  for entry in "${HIGH_PRIORITY[@]}"; do
    IFS='|' read -r crate deps size status <<< "$entry"
    status_display="Not Started"
    if [ "$status" == "partial" ]; then
      status_display="Partial"
    fi
    printf "%-35s %-15s %-15s %-15s\n" "$crate" "$deps" "$size" "$status_display"
  done
  
  echo -e "\n${BOLD}${YELLOW}Medium Priority Targets (uses core/types but fewer dependencies):${NC}"
  printf "%-35s %-15s %-15s %-15s\n" "Crate" "Dependencies" "Size (LoC)" "Migration Status"
  printf "%-35s %-15s %-15s %-15s\n" "$(printf '=%.0s' {1..35})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})"
  
  for entry in "${MEDIUM_PRIORITY[@]:0:10}"; do
    IFS='|' read -r crate deps size status <<< "$entry"
    status_display="Not Started"
    if [ "$status" == "partial" ]; then
      status_display="Partial"
    fi
    printf "%-35s %-15s %-15s %-15s\n" "$crate" "$deps" "$size" "$status_display"
  done
  
  # Generate JSON for further processing
  generate_json
  
  echo -e "\n${BOLD}Generated priorities file at:${NC} $OUTPUT_FILE"
  echo "This file can be used by other scripts to track migration progress."
  
  # Give concrete next steps
  echo -e "\n${BOLD}Recommended Next Crates to Migrate:${NC}"
  if [ ${#HIGH_PRIORITY[@]} -gt 0 ]; then
    IFS='|' read -r crate deps size status <<< "${HIGH_PRIORITY[0]}"
    echo "1. $crate (heavily depended on with $deps dependents)"
  fi
  if [ ${#HIGH_PRIORITY[@]} -gt 1 ]; then
    IFS='|' read -r crate deps size status <<< "${HIGH_PRIORITY[1]}"
    echo "2. $crate (heavily depended on with $deps dependents)"
  fi
  if [ ${#HIGH_PRIORITY[@]} -gt 2 ]; then
    IFS='|' read -r crate deps size status <<< "${HIGH_PRIORITY[2]}"
    echo "3. $crate (heavily depended on with $deps dependents)"
  fi
}

# Generate JSON output
generate_json() {
  # Start JSON object
  echo "{" > "$OUTPUT_FILE"
  echo "  \"high_priority\": [" >> "$OUTPUT_FILE"
  
  # Add high priority crates
  local first=true
  for entry in "${HIGH_PRIORITY[@]}"; do
    IFS='|' read -r crate deps size status <<< "$entry"
    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> "$OUTPUT_FILE"
    fi
    echo -n "    {\"name\": \"$crate\", \"dependencies\": $deps, \"size\": $size, \"status\": \"$status\"}" >> "$OUTPUT_FILE"
  done
  
  echo >> "$OUTPUT_FILE"
  echo "  ]," >> "$OUTPUT_FILE"
  echo "  \"medium_priority\": [" >> "$OUTPUT_FILE"
  
  # Add medium priority crates
  first=true
  for entry in "${MEDIUM_PRIORITY[@]}"; do
    IFS='|' read -r crate deps size status <<< "$entry"
    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> "$OUTPUT_FILE"
    fi
    echo -n "    {\"name\": \"$crate\", \"dependencies\": $deps, \"size\": $size, \"status\": \"$status\"}" >> "$OUTPUT_FILE"
  done
  
  echo >> "$OUTPUT_FILE"
  echo "  ]," >> "$OUTPUT_FILE"
  echo "  \"low_priority\": [" >> "$OUTPUT_FILE"
  
  # Add first 20 low priority crates
  first=true
  for entry in "${LOW_PRIORITY[@]:0:20}"; do
    IFS='|' read -r crate deps size status <<< "$entry"
    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> "$OUTPUT_FILE"
    fi
    echo -n "    {\"name\": \"$crate\", \"dependencies\": $deps, \"size\": $size, \"status\": \"$status\"}" >> "$OUTPUT_FILE"
  done
  
  echo >> "$OUTPUT_FILE"
  echo "  ]," >> "$OUTPUT_FILE"
  
  # Add already migrated crates
  echo "  \"migrated\": [" >> "$OUTPUT_FILE"
  first=true
  for crate in "${ALREADY_MIGRATED[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> "$OUTPUT_FILE"
    fi
    echo -n "    \"$crate\"" >> "$OUTPUT_FILE"
  done
  
  echo >> "$OUTPUT_FILE"
  echo "  ]" >> "$OUTPUT_FILE"
  echo "}" >> "$OUTPUT_FILE"
}

# Run main function
main