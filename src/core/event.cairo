use starknet::ContractAddress;
use core::zeroable::NonZero;
use core::option::Option;
use crate::interface::i_core::{TaskStatus};

/// Emits when a provider is assigned to a Task.
#[derive(Drop, starknet::Event)]
pub struct ProviderRegistered {
    #[key]
    pub id: NonZero<felt252>,
    pub address: ContractAddress,
}

/// Represents when a Task has an updated status.
#[derive(Drop, starknet::Event)]
pub struct StatusUpdate {
    #[key]
    pub id: NonZero<felt252>,
    pub status: TaskStatus,
}

/// Represents when a Task has a solution submission.
#[derive(Drop, starknet::Event)]
pub struct WorkSubmission {
    pub id: NonZero<felt252>,
    pub chain_hash: NonZero<felt252>,
}

/// Represents when a Task is registered.
#[derive(Drop, starknet::Event)]
pub struct TaskRegistered {
    pub id: NonZero<felt252>,
    #[key]
    pub initiator: ContractAddress,
    pub provider: ContractAddress,
    pub amount_funded: NonZero<u256>,
}
