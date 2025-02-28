#\!/bin/bash

# Verify that sui-json-rpc-tests was updated correctly
set -e

echo "=== Verifying sui-json-rpc-tests migration ==="

echo "Checking Cargo.toml for mysocial-core dependency..."
grep -q "mysocial-core.workspace = true" "crates/sui-json-rpc-tests/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-core dependency added to Cargo.toml"
else
  echo "❌ mysocial-core dependency not found in Cargo.toml"
  exit 1
fi

echo "Checking Cargo.toml for mysocial-types dependency..."
grep -q "mysocial-types.workspace = true" "crates/sui-json-rpc-tests/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-types dependency added to Cargo.toml"
else
  echo "❌ mysocial-types dependency not found in Cargo.toml"
  exit 1
fi

echo "Checking Cargo.toml for mysocial-protocol-config dependency..."
grep -q "mysocial-protocol-config.workspace = true" "crates/sui-json-rpc-tests/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-protocol-config dependency added to Cargo.toml"
else
  echo "❌ mysocial-protocol-config dependency not found in Cargo.toml"
  exit 1
fi

echo "Checking for backward compatibility comments..."
grep -q "sui-core.workspace = true # Keep for backward compatibility" "crates/sui-json-rpc-tests/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ Backward compatibility comment added for sui-core"
else
  echo "❌ Backward compatibility comment not found for sui-core"
  exit 1
fi

grep -q "sui-types.workspace = true # Keep for backward compatibility" "crates/sui-json-rpc-tests/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ Backward compatibility comment added for sui-types"
else
  echo "❌ Backward compatibility comment not found for sui-types"
  exit 1
fi

grep -q "sui-protocol-config.workspace = true # Keep for backward compatibility" "crates/sui-json-rpc-tests/Cargo.toml"
if [ $? -eq 0 ]; then
  echo "✅ Backward compatibility comment added for sui-protocol-config"
else
  echo "❌ Backward compatibility comment not found for sui-protocol-config"
  exit 1
fi

echo "=== All checks passed\! sui-json-rpc-tests has been migrated successfully ==="
