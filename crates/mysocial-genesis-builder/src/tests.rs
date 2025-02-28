#[cfg(test)]
mod tests {
    use anyhow::Result;
    use fastcrypto::traits::KeyPair;
    
    // Conditional imports
    #[cfg(feature = "use-mysocial")]
    use mysocial_config::local_ip_utils;
    #[cfg(feature = "use-mysocial")]
    use mysocial_config::node::DEFAULT_COMMISSION_RATE;
    #[cfg(feature = "use-mysocial")]
    use mysocial_config::node::DEFAULT_VALIDATOR_GAS_PRICE;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::base_types::SuiAddress;
    #[cfg(feature = "use-mysocial")]
    use mysocial_types::crypto::{
        generate_proof_of_possession, get_key_pair_from_rng, AccountKeyPair, AuthorityKeyPair,
        NetworkKeyPair,
    };

    #[cfg(not(feature = "use-mysocial"))]
    use sui_config::local_ip_utils;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_config::node::DEFAULT_COMMISSION_RATE;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_config::node::DEFAULT_VALIDATOR_GAS_PRICE;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::base_types::SuiAddress;
    #[cfg(not(feature = "use-mysocial"))]
    use sui_types::crypto::{
        generate_proof_of_possession, get_key_pair_from_rng, AccountKeyPair, AuthorityKeyPair,
        NetworkKeyPair,
    };

    use crate::validator_info::ValidatorInfo;
    use crate::Builder;
    
    #[test]
    fn test_builder_create() -> Result<()> {
        let key: AuthorityKeyPair = get_key_pair_from_rng(&mut rand::rngs::OsRng).1;
        let worker_key: NetworkKeyPair = get_key_pair_from_rng(&mut rand::rngs::OsRng).1;
        let account_key: AccountKeyPair = get_key_pair_from_rng(&mut rand::rngs::OsRng).1;
        let network_key: NetworkKeyPair = get_key_pair_from_rng(&mut rand::rngs::OsRng).1;
        
        let validator = ValidatorInfo {
            name: "test-validator".into(),
            protocol_key: key.public().into(),
            worker_key: worker_key.public().clone(),
            account_address: SuiAddress::from(account_key.public()),
            network_key: network_key.public().clone(),
            gas_price: DEFAULT_VALIDATOR_GAS_PRICE,
            commission_rate: DEFAULT_COMMISSION_RATE,
            network_address: local_ip_utils::new_local_tcp_address_for_testing(),
            p2p_address: local_ip_utils::new_local_udp_address_for_testing(),
            narwhal_primary_address: local_ip_utils::new_local_udp_address_for_testing(),
            narwhal_worker_address: local_ip_utils::new_local_udp_address_for_testing(),
            description: String::new(),
            image_url: String::new(),
            project_url: String::new(),
        };
        
        let pop = generate_proof_of_possession(&key, account_key.public().into());
        let _builder = Builder::new().add_validator(validator, pop);
        
        // Successfully created a builder instance with the validator added
        Ok(())
    }
}