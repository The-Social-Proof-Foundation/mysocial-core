#\!/bin/bash

# Verify that sui-indexer-alt-restorer was updated correctly
set -e

echo "=== Verifying sui-indexer-alt-restorer migration ==="

echo "Checking Cargo.toml for mysocial-core dependency..."
grep -q "mysocial-core.workspace = true" "crates/sui-indexer-alt-restorer/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-core dependency added to Cargo.toml"
else
  echo "❌ mysocial-core dependency not found in Cargo.toml"
  exit 1
fi

echo "Checking for backward compatibility comment..."
grep -q "sui-core.workspace = true # Keep for backward compatibility" "crates/sui-indexer-alt-restorer/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ Backward compatibility comment added for sui-core"
else
  echo "❌ Backward compatibility comment not found for sui-core"
  exit 1
fi

echo "Checking snapshot.rs for LiveObject import from mysocial-core..."
grep -q "use mysocial_core::alias::LiveObject" "crates/sui-indexer-alt-restorer/src/snapshot.rs"
if [ $? -eq 0 ]; then
  echo "✅ LiveObject is correctly imported from mysocial-core"
else
  echo "❌ LiveObject is not imported from mysocial-core"
  exit 1
fi

echo "=== All checks passed\! sui-indexer-alt-restorer has been migrated successfully ==="
