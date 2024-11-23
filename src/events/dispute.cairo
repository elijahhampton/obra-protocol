use starknet::ContractAddress;

// --- WorkCore Dispute Events ---
#[event]
#[derive(Drop, starknet::Event)]
pub enum DisputeEvent {
   DisputeCreated: DisputeCreated,
   DisputeResolved: DisputeResolved, 
   DisputeTimedOut: DisputeTimedOut,
   DisputeCancelled: DisputeCancelled
}

#[derive(Drop, starknet::Event)]
struct DisputeCreated {
   dispute_id: u256,
   market_id: felt252,
   creator: ContractAddress,
   respondent: ContractAddress,
   created_at: u64
}

#[derive(Drop, starknet::Event)]
struct DisputeResolved {
   dispute_id: u256,
   winner: ContractAddress,
   resolved_at: u64
}

#[derive(Drop, starknet::Event)]
struct DisputeTimedOut {
   dispute_id: u256,
   timed_out_at: u64
}

#[derive(Drop, starknet::Event)]
struct DisputeCancelled {
   dispute_id: u256,
   cancelled_at: u64,
   reason: felt252
}