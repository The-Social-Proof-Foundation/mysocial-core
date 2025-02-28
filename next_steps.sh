#\!/bin/bash

# Display what to work on next based on the current status

echo "===== MYSOCIAL MIGRATION NEXT STEPS ====="
echo ""
echo "HIGH PRIORITY CRATES TO WORK ON NEXT:"
ls -la crates/migrated/priorities/high/ | grep -v "total\|README\|\.\.$\|\.$" | awk '{print $NF}' | sed 's/^/  - /'

echo ""
echo "RECOMMENDED APPROACH:"
echo "1. Pick one high priority crate from the list above"
echo "2. Modify its Cargo.toml to add mysocial-core/types dependencies"
echo "3. Update imports to use mysocial_* instead of sui_*"
echo "4. Verify imports with verification scripts"
echo "5. Run migration status update:"
echo "   ./migration_status.sh && ./organize_crates.sh"
echo ""
echo "See crates/migrated/priorities/high/README.md for specific details on each high priority crate."
