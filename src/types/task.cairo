use starknet::ContractAddress;

/// The status of a task.
#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum WorkStatus {
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
    pub status: Option<WorkStatus>,
    pub metadata: Option<felt252>,
    pub geo_point: Option<(i64, i64)>
}