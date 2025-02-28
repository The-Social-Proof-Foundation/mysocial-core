#\!/bin/bash

# Verify imports in updated crates
set -e

echo "=== Verifying imports in updated crates ==="

echo "Checking sui-telemetry for correct imports..."
grep -q "use mysocial_core::alias::AuthorityState" "crates/sui-telemetry/src/lib.rs"
if [ $? -eq 0 ]; then
  echo "✅ AuthorityState is correctly imported from mysocial-core in sui-telemetry"
else
  echo "❌ AuthorityState is not correctly imported from mysocial-core in sui-telemetry"
  exit 1
fi

echo "Checking sui-benchmark for correct imports..."
grep -q "use mysocial_core::" "crates/sui-benchmark/src/lib.rs"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-core is correctly imported in sui-benchmark"
else
  echo "❌ mysocial-core is not correctly imported in sui-benchmark"
  exit 1
fi

echo "Checking sui-cluster-test for correct imports..."
grep -q "use mysocial_types::" "crates/sui-cluster-test/src/lib.rs"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-types is correctly imported in sui-cluster-test"
else
  echo "❌ mysocial-types is not correctly imported in sui-cluster-test"
  exit 1
fi

echo "Checking sui-replay for correct imports..."
grep -q "use mysocial_core::" "crates/sui-replay/src/replay.rs"
if [ $? -eq 0 ]; then
  echo "✅ mysocial-core is correctly imported in sui-replay"
else
  echo "❌ mysocial-core is not correctly imported in sui-replay"
  exit 1
fi

echo "=== All verifications passed\! ==="
