use starknet::ContractAddress;
use super::solution::{Solution};
// --- WorkCore Disputes ---
#[derive(Drop, Serde, starknet::Store)]
pub struct DisputeConfig {
    pub resolution_timeout: u64,
}


#[derive(Drop, Serde, starknet::Store)]
pub struct Dispute {
    market_id: felt252,
    solution_type: Solution,
    creator: ContractAddress,
    respondent: ContractAddress,
    status: DisputeStatus,
    created_at: u64,
    resolved_at: Option<u64>,
    winner: Option<ContractAddress>
}

#[derive(Drop, Serde, starknet::Store)]
#[allow(starknet::store_no_default_variant)]
pub enum DisputeStatus {
    Active,
    Resolved,
    Cancelled
}