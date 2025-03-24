use core::zeroable::NonZero;
use starknet::ContractAddress;

/// Represents a market
#[derive(starknet::Store, Serde, Drop)]
pub struct Market {
    pub id: u64,
    pub m_type: MarketType,
    pub addr: ContractAddress
}

/// Represents different variants for the types of markets supported.
#[derive(starknet::Store, Serde, Clone, Drop, Destruct)]
#[allow(starknet::store_no_default_variant)]
pub enum MarketType {
    Basic, // Simple, one-off tasks (e.g., freelance jobs)
    RealTime, // Immediate, time-sensitive tasks (e.g., ride-sharing)
    Bounty, // Competitive tasks with winner-takes-all rewards (e.g., design contests)
    _Subscription, // Recurring tasks with ongoing payments (e.g., hosting services)
    _Collaborative, // Multi-party tasks requiring teamwork (e.g., open-source projects)
    _Auction, // Tasks assigned via bidding (e.g., reverse auctions for lowest bid)
    _Verified, // Tasks with strict quality or identity checks (e.g., certified deliveries)
    _Escrow, // Long-term tasks with milestone payments (e.g., construction projects)
    _PeerToPeer, // Direct provider-to-provider task chaining (e.g., service referrals)
    _Gamified // Tasks with competitive or reward-based incentives (e.g., leaderboards)
}

/// A public external API related to market functionality.
#[starknet::interface]
pub trait IMarket<TContractState> {
    /// Signals a new task has been created in the market.
    fn new_task(ref self: TContractState);

    /// Submits task completion and MUST call core.finalize_task(task_id, success)
    /// Maintainers: Use asserts for critical invariants (e.g., caller verification),
    /// but test thoroughly to avoid unintended panics that revert the transaction
    fn submit_completion(
        ref self: TContractState, task_id: u64, verification_hash: NonZero<felt252>,
    );

    /// Returns the market type.
    fn market_type(ref self: TContractState) -> MarketType;

    /// Receives fee share from Core for a task; updates market balance
    /// Maintainers: Accumulate amount in storage; avoid complex logic or panics here
    fn pay_fee(ref self: TContractState, task_id: felt252, amount: u256);

    /// Optional hook: Validates task before creation; returns 1 to approve, 0 to reject
    /// Maintainers: Avoid panics unless critical (e.g., security);
    fn pre_task_creation(
        self: @TContractState, task_id: felt252, description: felt252, reward: felt252,
    ) -> felt252;

    /// Optional hook: Reacts after task creation (e.g., logging, notifications)
    /// Maintainers: Keep non-critical; panics revert Core transaction
    fn post_task_creation(ref self: TContractState, task_id: felt252);

    /// Optional hook: Validates provider before assignment; returns 1 to approve, 0 to reject
    /// Maintainers: Avoid panics unless essential;
    fn pre_task_assignment(self: @TContractState, task_id: felt252, provider: felt252) -> felt252;

    /// Optional hook: Reacts after provider assignment (e.g., start timer)
    /// Maintainers: Keep non-critical; panics revert Core transaction
    fn post_task_assignment(ref self: TContractState, task_id: felt252, provider: felt252);

    /// Resolves a dispute for a task_id.
    /// NOTE: This function must call finalize_task to officially `finalizw` the task and update
    /// the global provider metrics. Task resolved from dispute will not result in a call to pay_fee
    /// from core.
    /// Returns 0 for no support, anything else for support.
    /// - See src/interface/i_core.cairo
    fn supports_disputes(self: @TContractState) -> u8;

    /// Indicates if a Market supports hooks.
    /// Returns 0 for no support, anything else for support.
    fn supports_hooks(self: @TContractState) -> u8;

    /// Initiaites a dispute for a task_id
    fn initiate_dispute(ref self: TContractState, task_id: felt252, reason: felt252);

    /// Indicates if Market supports reputation management
    fn supports_reputation_management(self: @TContractState) -> u8;

    /// Resolves a dispute for a task_id and MUST call core.finalize_task(task_id, success)
    fn resolve_dispute(ref self: TContractState, task_id: felt252, approve: felt252);
}

