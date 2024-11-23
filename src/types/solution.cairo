use starknet::ContractAddress;

// Solutions representing the differnet type of work
#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, starknet::Store, PartialEq)]
pub enum Solution {
    Uri,
    Coordinates
}

// --- WorkCore Solutions ---
#[derive(Serde, starknet::Store)]
pub struct SolutionKey {
    pub key_high: felt252,
    pub key_low: felt252
}