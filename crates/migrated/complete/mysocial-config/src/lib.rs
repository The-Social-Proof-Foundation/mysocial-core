// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Context;
use anyhow::Result;
use serde::de::DeserializeOwned;
use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};
use tracing::trace;

pub mod certificate_deny_config;
pub mod genesis;
pub mod local_ip_utils;
pub mod node;
pub mod node_config_metrics;
pub mod object_storage_config;
pub mod p2p;
pub mod transaction_deny_config;
pub mod verifier_signing_config;

pub use node::{ConsensusConfig, ExecutionCacheConfig, NodeConfig};
use mysocial_types::multiaddr::Multiaddr;

const MYSO_DIR: &str = ".mysocial";
pub const MYSO_CONFIG_DIR: &str = "mysocial_config";
pub const MYSO_NETWORK_CONFIG: &str = "network.yaml";
pub const MYSO_FULLNODE_CONFIG: &str = "fullnode.yaml";
pub const MYSO_CLIENT_CONFIG: &str = "client.yaml";
pub const MYSO_KEYSTORE_FILENAME: &str = "mysocial.keystore";
pub const MYSO_KEYSTORE_ALIASES_FILENAME: &str = "mysocial.aliases";
pub const MYSO_BENCHMARK_GENESIS_GAS_KEYSTORE_FILENAME: &str = "benchmark.keystore";
pub const MYSO_GENESIS_FILENAME: &str = "genesis.blob";
pub const MYSO_DEV_NET_URL: &str = "https://fullnode.devnet.mysocial.io:443";

// Backward compatibility aliases
pub const SUI_DIR: &str = MYSO_DIR;
pub const SUI_CONFIG_DIR: &str = MYSO_CONFIG_DIR;
pub const SUI_NETWORK_CONFIG: &str = MYSO_NETWORK_CONFIG;
pub const SUI_FULLNODE_CONFIG: &str = MYSO_FULLNODE_CONFIG;
pub const SUI_CLIENT_CONFIG: &str = MYSO_CLIENT_CONFIG;
pub const SUI_KEYSTORE_FILENAME: &str = MYSO_KEYSTORE_FILENAME;
pub const SUI_KEYSTORE_ALIASES_FILENAME: &str = MYSO_KEYSTORE_ALIASES_FILENAME;
pub const SUI_BENCHMARK_GENESIS_GAS_KEYSTORE_FILENAME: &str = MYSO_BENCHMARK_GENESIS_GAS_KEYSTORE_FILENAME;
pub const SUI_GENESIS_FILENAME: &str = MYSO_GENESIS_FILENAME;
pub const SUI_DEV_NET_URL: &str = MYSO_DEV_NET_URL;

pub const AUTHORITIES_DB_NAME: &str = "authorities_db";
pub const CONSENSUS_DB_NAME: &str = "consensus_db";
pub const FULL_NODE_DB_PATH: &str = "full_node_db";

pub fn mysocial_config_dir() -> Result<PathBuf, anyhow::Error> {
    match std::env::var_os("MYSOCIAL_CONFIG_DIR").or_else(|| std::env::var_os("SUI_CONFIG_DIR")) {
        Some(config_env) => Ok(config_env.into()),
        None => match dirs::home_dir() {
            Some(v) => Ok(v.join(MYSO_DIR).join(MYSO_CONFIG_DIR)),
            None => anyhow::bail!("Cannot obtain home directory path"),
        },
    }
    .and_then(|dir| {
        if !dir.exists() {
            fs::create_dir_all(dir.clone())?;
        }
        Ok(dir)
    })
}

// Backward compatibility alias
pub fn sui_config_dir() -> Result<PathBuf, anyhow::Error> {
    mysocial_config_dir()
}

/// Check if the genesis blob exists in the given directory or the default directory.
pub fn genesis_blob_exists(config_dir: Option<PathBuf>) -> bool {
    if let Some(dir) = config_dir {
        dir.join(MYSO_GENESIS_FILENAME).exists()
    } else if let Some(config_env) = std::env::var_os("MYSOCIAL_CONFIG_DIR").or_else(|| std::env::var_os("SUI_CONFIG_DIR")) {
        Path::new(&config_env).join(MYSO_GENESIS_FILENAME).exists()
    } else if let Some(home) = dirs::home_dir() {
        let mut config = PathBuf::new();
        config.push(&home);
        config.extend([MYSO_DIR, MYSO_CONFIG_DIR, MYSO_GENESIS_FILENAME]);
        config.exists()
    } else {
        false
    }
}

pub fn validator_config_file(address: Multiaddr, i: usize) -> String {
    multiaddr_to_filename(address).unwrap_or(format!("validator-config-{}.yaml", i))
}

pub fn ssfn_config_file(address: Multiaddr, i: usize) -> String {
    multiaddr_to_filename(address).unwrap_or(format!("ssfn-config-{}.yaml", i))
}

fn multiaddr_to_filename(address: Multiaddr) -> Option<String> {
    if let Some(hostname) = address.hostname() {
        if let Some(port) = address.port() {
            return Some(format!("{}-{}.yaml", hostname, port));
        }
    }
    None
}

pub trait Config
where
    Self: DeserializeOwned + Serialize,
{
    fn persisted(self, path: &Path) -> PersistedConfig<Self> {
        PersistedConfig {
            inner: self,
            path: path.to_path_buf(),
        }
    }

    fn load<P: AsRef<Path>>(path: P) -> Result<Self, anyhow::Error> {
        let path = path.as_ref();
        trace!("Reading config from {}", path.display());
        let reader = fs::File::open(path)
            .with_context(|| format!("Unable to load config from {}", path.display()))?;
        Ok(serde_yaml::from_reader(reader)?)
    }

    fn save<P: AsRef<Path>>(&self, path: P) -> Result<(), anyhow::Error> {
        let path = path.as_ref();
        trace!("Writing config to {}", path.display());
        let config = serde_yaml::to_string(&self)?;
        fs::write(path, config)
            .with_context(|| format!("Unable to save config to {}", path.display()))?;
        Ok(())
    }
}

pub struct PersistedConfig<C> {
    inner: C,
    path: PathBuf,
}

impl<C> PersistedConfig<C>
where
    C: Config,
{
    pub fn read(path: &Path) -> Result<C, anyhow::Error> {
        Config::load(path)
    }

    pub fn save(&self) -> Result<(), anyhow::Error> {
        self.inner.save(&self.path)
    }

    pub fn into_inner(self) -> C {
        self.inner
    }

    pub fn path(&self) -> &Path {
        &self.path
    }
}

impl<C> std::ops::Deref for PersistedConfig<C> {
    type Target = C;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl<C> std::ops::DerefMut for PersistedConfig<C> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.inner
    }
}
