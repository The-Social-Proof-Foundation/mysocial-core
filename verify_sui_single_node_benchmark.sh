#\!/bin/bash

# Verify that sui-single-node-benchmark was updated correctly
set -e

echo "=== Verifying sui-single-node-benchmark migration ==="

echo "Checking Cargo.toml for mysocial-core dependency..."
grep -q "mysocial-core.workspace = true" "crates/sui-single-node-benchmark/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-core dependency added to Cargo.toml"
else
  echo "❌ mysocial-core dependency not found in Cargo.toml"
  exit 1
fi

echo "Checking Cargo.toml for mysocial-types dependency..."
grep -q "mysocial-types.workspace = true" "crates/sui-single-node-benchmark/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-types dependency added to Cargo.toml"
else
  echo "❌ mysocial-types dependency not found in Cargo.toml"
  exit 1
fi

echo "Checking Cargo.toml for mysocial-protocol-config dependency (dev-dependencies)..."
grep -q "mysocial-protocol-config.workspace = true" "crates/sui-single-node-benchmark/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-protocol-config dependency added to Cargo.toml"
else
  echo "❌ mysocial-protocol-config dependency not found in Cargo.toml"
  exit 1
fi

echo "Checking for backward compatibility comments..."
grep -q "sui-core.workspace = true # Keep for backward compatibility" "crates/sui-single-node-benchmark/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ Backward compatibility comment added for sui-core"
else
  echo "❌ Backward compatibility comment not found for sui-core"
  exit 1
fi

grep -q "sui-types.workspace = true # Keep for backward compatibility" "crates/sui-single-node-benchmark/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ Backward compatibility comment added for sui-types"
else
  echo "❌ Backward compatibility comment not found for sui-types"
  exit 1
fi

grep -q "sui-protocol-config.workspace = true # Keep for backward compatibility" "crates/sui-single-node-benchmark/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ Backward compatibility comment added for sui-protocol-config"
else
  echo "❌ Backward compatibility comment not found for sui-protocol-config"
  exit 1
fi

echo "Checking single_node.rs for mysocial-core imports..."
grep -q "use mysocial_core::authority::authority_per_epoch_store::AuthorityPerEpochStore" "crates/sui-single-node-benchmark/src/single_node.rs"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-core imports updated in single_node.rs"
else
  echo "❌ mysocial-core imports not updated in single_node.rs"
  exit 1
fi

echo "Checking single_node.rs for mysocial-types imports..."
grep -q "use mysocial_types::base_types" "crates/sui-single-node-benchmark/src/single_node.rs"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-types imports updated in single_node.rs"
else
  echo "❌ mysocial-types imports not updated in single_node.rs"
  exit 1
fi

echo "Checking mock_storage.rs for mysocial-core imports..."
grep -q "use mysocial_core::authority::authority_per_epoch_store::AuthorityPerEpochStore" "crates/sui-single-node-benchmark/src/mock_storage.rs"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-core imports updated in mock_storage.rs"
else
  echo "❌ mysocial-core imports not updated in mock_storage.rs"
  exit 1
fi

echo "Checking mock_storage.rs for mysocial-types imports..."
grep -q "use mysocial_types::base_types" "crates/sui-single-node-benchmark/src/mock_storage.rs"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-types imports updated in mock_storage.rs"
else
  echo "❌ mysocial-types imports not updated in mock_storage.rs"
  exit 1
fi

echo "=== All checks passed\! sui-single-node-benchmark has been migrated successfully ==="
