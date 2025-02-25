use crate::types::task::WorkStatus;
use starknet::ContractAddress;
use core::zeroable::NonZero;
use core::option::Option;

#[derive(Drop, starknet::Event)]
pub struct ProviderRegistered {
    #[key]
    pub id: NonZero<felt252>,
    pub address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct StatusUpdate {
    #[key]
    pub id: NonZero<felt252>,
    pub status: WorkStatus,
}

#[derive(Drop, starknet::Event)]
pub struct WorkSubmission {
    pub id: NonZero<felt252>,
    pub chain_hash: NonZero<felt252>,
}

#[derive(Drop, starknet::Event)]
pub struct TaskRegistered {
    pub id: NonZero<felt252>,
    #[key]
    pub initiator: ContractAddress,
    pub provider: ContractAddress,
    pub amount_funded: NonZero<u256>,
}

#[derive(Drop, starknet::Event)]
pub struct SolutionVerified {
    #[key]
    pub task_id: NonZero<felt252>,
    pub hash_matches: bool,
}
