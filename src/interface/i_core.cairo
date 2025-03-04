use starknet::ContractAddress;
use core::zeroable::NonZero;

/// The status of a task.
#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum TaskStatus {
    Created,
    Occupied,
    ApprovalPending,
    SubmissionDenied,
    Completed,
    Closed,
}

/// Represents work that has been registered on chain.
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct Task {
    pub id: NonZero<felt252>,
    pub initiator: ContractAddress,
    pub provider: ContractAddress,
    pub initiator_sig: felt252,
    pub provider_sig: felt252,
    pub reward: NonZero<u256>,
    pub status: Option<TaskStatus>,
    pub metadata: Option<felt252>,
    pub market: ContractAddress
}

#[starknet::interface]
pub trait ICore<TContractState> {
    fn register_task(ref self: TContractState, task: Task);
    fn assign_task(ref self: TContractState, task_id: NonZero<felt252>, provider: ContractAddress);
    fn get_task(ref self: TContractState, task_id: NonZero<felt252>) -> Task;
    fn finalize_task(
        ref self: TContractState, task_id: NonZero<felt252>, verification_hash: NonZero<felt252>,
    );
}

#[derive(Serde, Drop, Destruct)]
pub enum MarketType {
    Basic
}

#[starknet::interface]
pub trait ICoreMarket<TContractState> {
    fn register_market(ref self: TContractState, market: ContractAddress, market_type: MarketType);
}

pub trait ICoreFeeManagement<TContractState> {
    fn set_fee_percentage(ref self: TContractState, feePercentage: u256);
    fn get_fee_percentage(ref self: TContractState) -> u256;
    fn distribute_fees(ref self: TContractState, market: ContractAddress, amount: u256);
}