use core::zeroable::NonZero;

/// Represents different variants for the types of markets supported.
#[derive(starknet::Store, Serde, Drop, Destruct)]
pub enum MarketType {
    Basic,
}

/// A public external API related to market functionality.
#[starknet::interface]
pub trait IMarket<TContractState> {
    /// Submit a hash for a task_id representing the solution string;
    /// NOTE: This function must call finalize_task to officially `finalize` the task and update
    /// global provider metrics / receive finalization fees.
    /// - See src/interface/i_core.cairo
    fn submit_completion(
        ref self: TContractState, task_id: NonZero<felt252>, verification_hash: NonZero<felt252>,
    );

    /// Pay fee to the core.
    fn pay_fee(ref self: TContractState, task_id: u256);

    /// Returns the market type.
    fn market_type(ref self: TContractState) -> MarketType;
}
