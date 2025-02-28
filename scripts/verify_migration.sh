#!/bin/bash
# verify_migration.sh - Script to verify MySocial migration progress and quality
# 
# This script helps verify the migration progress of renamed crates,
# checking for consistency of imports and dependencies.

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
  echo -e "\n${BOLD}${CYAN}$1${NC}"
  echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

# Crate name to check, can be provided as argument
CRATE=${1:-""}

if [ -z "$CRATE" ]; then
  print_header "MySocial Migration Verification Tool"
  echo "Usage: $0 <crate-name>"
  echo "Example: $0 sui-json-rpc-tests"
  exit 1
fi

print_header "Verifying migration for $CRATE"

# Check if crate exists
if [ ! -d "crates/$CRATE" ]; then
  print_error "Crate $CRATE not found in crates directory"
  exit 1
fi

# Check if Cargo.toml has mysocial dependencies
echo "Checking Cargo.toml for mysocial dependencies..."
if grep -q "mysocial-core" "crates/$CRATE/Cargo.toml"; then
  print_success "Cargo.toml includes mysocial-core dependency"
else
  print_warning "Cargo.toml does not include mysocial-core dependency"
fi

if grep -q "mysocial-types" "crates/$CRATE/Cargo.toml"; then
  print_success "Cargo.toml includes mysocial-types dependency"
else
  print_warning "Cargo.toml does not include mysocial-types dependency"
fi

if grep -q "mysocial-protocol-config" "crates/$CRATE/Cargo.toml"; then
  print_success "Cargo.toml includes mysocial-protocol-config dependency"
else
  print_warning "Cargo.toml does not include mysocial-protocol-config dependency"
fi

# Check if source files use mysocial imports rather than sui imports
echo -e "\nChecking source files for proper imports..."

# First verify we can find source files
SRC_FILES=$(find "crates/$CRATE/src" -name "*.rs" 2>/dev/null || echo "")
if [ -z "$SRC_FILES" ] && [ -d "crates/$CRATE/tests" ]; then
  SRC_FILES=$(find "crates/$CRATE/tests" -name "*.rs" 2>/dev/null || echo "")
fi

if [ -z "$SRC_FILES" ]; then
  print_error "No source files found for $CRATE"
  exit 1
fi

# Check for sui_types imports that should have been migrated
SUI_TYPES_IMPORTS=$(grep -r "use sui_types::" "crates/$CRATE" --include="*.rs" 2>/dev/null || echo "")
if [ -z "$SUI_TYPES_IMPORTS" ]; then
  print_success "No sui_types imports found (good)"
else
  print_error "Found sui_types imports that should be migrated to mysocial_types:"
  echo "$SUI_TYPES_IMPORTS"
fi

# Check for sui_core imports that should have been migrated
SUI_CORE_IMPORTS=$(grep -r "use sui_core::" "crates/$CRATE" --include="*.rs" 2>/dev/null || echo "")
if [ -z "$SUI_CORE_IMPORTS" ]; then
  print_success "No sui_core imports found (good)"
else
  print_error "Found sui_core imports that should be migrated to mysocial_core:"
  echo "$SUI_CORE_IMPORTS"
fi

# Check for sui_protocol_config imports that should have been migrated
SUI_PROTOCOL_IMPORTS=$(grep -r "use sui_protocol_config::" "crates/$CRATE" --include="*.rs" 2>/dev/null || echo "")
if [ -z "$SUI_PROTOCOL_IMPORTS" ]; then
  print_success "No sui_protocol_config imports found (good)"
else
  print_error "Found sui_protocol_config imports that should be migrated to mysocial_protocol_config:"
  echo "$SUI_PROTOCOL_IMPORTS"
fi

# Check if mysocial imports are actually used
MYSOCIAL_TYPES_IMPORTS=$(grep -r "use mysocial_types::" "crates/$CRATE" --include="*.rs" 2>/dev/null || echo "")
if [ -n "$MYSOCIAL_TYPES_IMPORTS" ]; then
  print_success "Found mysocial_types imports (good)"
else
  print_warning "No mysocial_types imports found - check if this crate should use mysocial-types"
fi

MYSOCIAL_CORE_IMPORTS=$(grep -r "use mysocial_core::" "crates/$CRATE" --include="*.rs" 2>/dev/null || echo "")
if [ -n "$MYSOCIAL_CORE_IMPORTS" ]; then
  print_success "Found mysocial_core imports (good)"
else
  print_warning "No mysocial_core imports found - check if this crate should use mysocial-core"
fi

# Run cargo check for individual crate to verify it compiles
# We only check that cargo can parse the crate due to the current issue with duplicate
# package names between sui-core and mysocial-core
echo -e "\nRunning cargo check-syntax for $CRATE..."
if cargo check-syntax -p "$CRATE" 2>&1 | grep -q 'error:'; then
  print_error "Cargo check-syntax for $CRATE failed"
else
  print_success "Cargo check-syntax for $CRATE passed"
fi

# Final report
echo -e "\n${BOLD}Migration Status Summary:${NC}"
if [ -z "$SUI_TYPES_IMPORTS" ] && [ -z "$SUI_CORE_IMPORTS" ] && [ -z "$SUI_PROTOCOL_IMPORTS" ]; then
  if [ -n "$MYSOCIAL_TYPES_IMPORTS" ] || [ -n "$MYSOCIAL_CORE_IMPORTS" ]; then
    echo -e "${GREEN}$CRATE appears to be fully migrated!${NC}"
  else
    echo -e "${YELLOW}$CRATE doesn't use any sui/mysocial types directly, further investigation needed.${NC}"
  fi
else
  echo -e "${RED}$CRATE still has old imports that need to be migrated.${NC}"
fi

echo -e "\nVerification complete."