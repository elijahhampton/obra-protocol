use starknet::ContractAddress;
use core::zeroable::NonZero;
use crate::interface::i_market::{MarketType};

/// Represents the state of a task from the moment it is registered.
#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum TaskState {
    Created,
    Occupied,
    ApprovalPending,
    SubmissionDenied,
    Completed,
    Closed,
}

/// A task that has been registered on chain.
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct Task {
    pub id: NonZero<felt252>,
    pub initiator: ContractAddress,
    pub provider: ContractAddress,
    pub initiator_sig: felt252,
    pub provider_sig: felt252,
    pub reward: NonZero<u256>,
    pub status: Option<TaskState>,
    pub metadata: Option<felt252>,
    pub market: ContractAddress,
}

/// A public external API related to core protocol functionality.
#[starknet::interface]
pub trait ICore<TContractState> {
    /// Registers a ContractAddress to the provider_registrar.
    fn register(ref self: TContractState);

    /// Registers a task in the global registrar and maps it to the underlying market it was created
    /// under.
    fn register_task(ref self: TContractState, task: Task, market: ContractAddress);

    /// Assigns a task to a service provider. assign_task will be called implicitly in register_task
    /// if the `Task` parameter has an assigned value for provider, otherwise, it can be called
    /// explicitly for Task that do not have a provider current assigned.
    fn assign_task(ref self: TContractState, task_id: NonZero<felt252>, provider: ContractAddress);

    /// Returns a task based on a task id.
    fn get_task(ref self: TContractState, task_id: NonZero<felt252>) -> Task;
}

/// A public external API related to escrow functionality.
#[starknet::interface]
pub trait IExternalEscrow<TContractState> {
    fn reward_addr(self: @TContractState) -> ContractAddress;
}

/// A public external API for related to interactions between the core contract
/// and market contracts.
#[starknet::interface]
pub trait ICoreMarket<TContractState> {
    /// Registers a market in the global registrar.
    /// Note: This method can only be called by an external contract.
    fn register_market(ref self: TContractState, market: ContractAddress, market_type: MarketType);

    /// Checks a stored solution hash against a verification hash to prove a task has been received.
    /// NOTE: This method can only be called by a registered market contract.
    fn finalize_task(
        ref self: TContractState, task_id: NonZero<felt252>, verification_hash: NonZero<felt252>,
    );
}

/// A private internal API related to fee management.
#[starknet::interface]
pub trait ICoreFeeManagement<TContractState> {
    /// Set the fee percentage for task registration.
    fn set_task_registration_fee_percentage(ref self: TContractState, fee_percentage: u8);

    /// Get the fee percentage for task registration.
    fn get_task_registration_fee_percentage(ref self: TContractState) -> u8;

    /// Distributes finalization fee to a market.
    fn distribute_finalization_reward(
        ref self: TContractState, market: ContractAddress, amount: u256,
    );
}
