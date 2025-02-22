use starknet::ContractAddress;

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, starknet::Store, PartialEq)]
pub enum Solution {
    Uri: felt252,
    Coordinates: (i64, i64),
}