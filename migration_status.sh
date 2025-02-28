#\!/bin/bash

# Analyze migration status and categorize crates
# Output formats: text (default), json (with --json flag)

OUTPUT_FORMAT="text"
if [ "$1" = "--json" ]; then
  OUTPUT_FORMAT="json"
fi

CRATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/crates" && pwd)"
MIGRATION_REPORT="migration_report.txt"
MIGRATION_JSON="migration_report.json"

# Arrays to store crate categorization
FULLY_MIGRATED=()
PARTIALLY_MIGRATED=()
NOT_MIGRATED=()

# Check if a crate is fully migrated (uses mysocial-core/types consistently)
is_fully_migrated() {
  local crate_dir="$1"
  local crate_name=$(basename "$crate_dir")
  
  # Skip directories that aren't crates
  if [ \! -f "$crate_dir/Cargo.toml" ]; then
    return 1
  fi
  
  # Skip mysocial-core and other special directories
  if [ "$crate_name" = "mysocial-core" ] || [ "$crate_name" = "mysocial-types" ] || [ "$crate_name" = "mysocial-protocol-config" ]; then
    return 0
  fi
  
  # Check for any mysocial_ imports
  if grep -r "use mysocial_" "$crate_dir/src" >/dev/null 2>&1; then
    # Also check if it still has sui-core dependencies not for compatibility
    if grep -r "use sui_core" "$crate_dir/src" | grep -v "# Keep for backward compatibility" >/dev/null 2>&1; then
      return 1
    else
      return 0
    fi
  else
    return 1
  fi
}

# Check if a crate is partially migrated
is_partially_migrated() {
  local crate_dir="$1"
  
  # Skip directories that aren't crates
  if [ \! -f "$crate_dir/Cargo.toml" ]; then
    return 1
  fi
  
  # Check for any mysocial_ imports
  if grep -r "use mysocial_" "$crate_dir/src" >/dev/null 2>&1; then
    return 0
  else
    # Check if this crate was explicitly mentioned in CLAUDE.md
    local crate_name=$(basename "$crate_dir")
    if grep -q "$crate_name" "$CRATES_DIR/../CLAUDE.md"; then
      return 0
    else
      return 1
    fi
  fi
}

# Process all directories in crates/
for crate_dir in "$CRATES_DIR"/*; do
  crate_name=$(basename "$crate_dir")
  
  # Skip non-directories
  if [ \! -d "$crate_dir" ]; then
    continue
  fi
  
  # Skip special directories
  if [ "$crate_name" = "migrated" ] || [ "$crate_name" = "to_migrate" ] || [ "$crate_name" = "target" ]; then
    continue
  fi
  
  if is_fully_migrated "$crate_dir"; then
    FULLY_MIGRATED+=("$crate_name")
  elif is_partially_migrated "$crate_dir"; then
    PARTIALLY_MIGRATED+=("$crate_name")
  else
    # Only include actual crates, not other directories
    if [ -f "$crate_dir/Cargo.toml" ]; then
      NOT_MIGRATED+=("$crate_name")
    fi
  fi
done

# Sort arrays
IFS=$'\n' 
FULLY_MIGRATED=($(sort <<<"${FULLY_MIGRATED[*]}"))
PARTIALLY_MIGRATED=($(sort <<<"${PARTIALLY_MIGRATED[*]}"))
NOT_MIGRATED=($(sort <<<"${NOT_MIGRATED[*]}"))
unset IFS

# Output results based on format
if [ "$OUTPUT_FORMAT" = "json" ]; then
  # Generate JSON output
  echo "{" > "$MIGRATION_JSON"
  echo "  \"fully_migrated\": [" >> "$MIGRATION_JSON"
  for ((i=0; i<${#FULLY_MIGRATED[@]}; i++)); do
    echo -n "    \"${FULLY_MIGRATED[$i]}\"" >> "$MIGRATION_JSON"
    if [ $i -lt $((${#FULLY_MIGRATED[@]}-1)) ]; then
      echo "," >> "$MIGRATION_JSON"
    else
      echo "" >> "$MIGRATION_JSON"
    fi
  done
  echo "  ]," >> "$MIGRATION_JSON"
  
  echo "  \"partially_migrated\": [" >> "$MIGRATION_JSON"
  for ((i=0; i<${#PARTIALLY_MIGRATED[@]}; i++)); do
    echo -n "    \"${PARTIALLY_MIGRATED[$i]}\"" >> "$MIGRATION_JSON"
    if [ $i -lt $((${#PARTIALLY_MIGRATED[@]}-1)) ]; then
      echo "," >> "$MIGRATION_JSON"
    else
      echo "" >> "$MIGRATION_JSON"
    fi
  done
  echo "  ]," >> "$MIGRATION_JSON"
  
  echo "  \"not_migrated\": [" >> "$MIGRATION_JSON"
  for ((i=0; i<${#NOT_MIGRATED[@]}; i++)); do
    echo -n "    \"${NOT_MIGRATED[$i]}\"" >> "$MIGRATION_JSON"
    if [ $i -lt $((${#NOT_MIGRATED[@]}-1)) ]; then
      echo "," >> "$MIGRATION_JSON"
    else
      echo "" >> "$MIGRATION_JSON"
    fi
  done
  echo "  ]" >> "$MIGRATION_JSON"
  echo "}" >> "$MIGRATION_JSON"
  
  echo "Migration status report generated in $MIGRATION_JSON"
else
  # Generate text output
  {
    echo "===== MYSOCIAL MIGRATION STATUS ====="
    echo ""
    echo "FULLY MIGRATED CRATES (${#FULLY_MIGRATED[@]}):"
    for crate in "${FULLY_MIGRATED[@]}"; do
      echo "  - $crate"
    done
    
    echo ""
    echo "PARTIALLY MIGRATED CRATES (${#PARTIALLY_MIGRATED[@]}):"
    for crate in "${PARTIALLY_MIGRATED[@]}"; do
      echo "  - $crate"
    done
    
    echo ""
    echo "NOT MIGRATED CRATES (${#NOT_MIGRATED[@]}):"
    for crate in "${NOT_MIGRATED[@]}"; do
      echo "  - $crate"
    done
    
    echo ""
    echo "Next steps:"
    echo "1. Complete migration of partially migrated crates"
    echo "2. Focus on high-priority non-migrated crates"
    echo "3. Consider symlinks in crates/migrated/ for better organization"
  } > "$MIGRATION_REPORT"
  
  echo "Migration status report generated in $MIGRATION_REPORT"
  cat "$MIGRATION_REPORT"
fi
