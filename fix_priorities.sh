#\!/bin/bash

# Manually set up the priority links
mkdir -p crates/migrated/priorities/high
mkdir -p crates/migrated/priorities/medium
mkdir -p crates/migrated/priorities/low

# High priority crates
HIGH_PRIORITY="sui-indexer-alt-restorer sui-json-rpc-tests sui-surfer transaction-fuzzer sui-single-node-benchmark sui-core"
MEDIUM_PRIORITY="sui-json-rpc sui-node sui-tool sui-network sui-faucet sui-genesis-builder"
LOW_PRIORITY="sui-proxy sui-rosetta sui-tls"

echo "Setting up priority symbolic links..."
echo "High priority crates:"
for crate in $HIGH_PRIORITY; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/priorities/high/$crate"
    echo "  - $crate"
  fi
done

echo "Medium priority crates:"
for crate in $MEDIUM_PRIORITY; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/priorities/medium/$crate"
    echo "  - $crate"
  fi
done

echo "Low priority crates:"
for crate in $LOW_PRIORITY; do
  if [ -d "crates/$crate" ]; then
    ln -sf "../../$crate" "crates/migrated/priorities/low/$crate"
    echo "  - $crate"
  fi
done

# List what's in the directories
echo "Contents of high priority directory:"
ls -la crates/migrated/priorities/high/
