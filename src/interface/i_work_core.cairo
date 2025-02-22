use starknet::ContractAddress;
use crate::types::task::{Task};
use core::zeroable::NonZero;

#[starknet::interface]
pub trait IWorkCore<TContractState> {
    fn register_task(ref self: TContractState, task: Task);
    fn assign(ref self: TContractState, task_id: NonZero<felt252>, provider: ContractAddress);
    fn verify_and_complete(ref self: TContractState, task_id: NonZero<felt252>, solution_hash: NonZero<felt252>) -> bool;
    fn submit(ref self: TContractState, task_id: NonZero<felt252>, verification_hash: NonZero<felt252>,);
}

