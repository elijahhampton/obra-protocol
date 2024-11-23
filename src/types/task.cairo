use starknet::ContractAddress;

/// Defines the difficulty and risk level of a task, which determines:
/// * Required reputation threshold (hk)
/// * Reputation rewards/penalties
/// * Qualification requirements
#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Clone, Serde, starknet::Store)]
pub enum TaskDifficulty {
    /// Entry level tasks for new users
    /// * Minimal reputation required (hk = 0)
    /// * Small reputation rewards
    /// * Limited reputation penalties
    Beginner,
    
    /// Standard tasks for established users
    /// * Basic reputation required (hk = 3)
    /// * Standard reputation rewards
    /// * Normal reputation penalties
    Basic,
    
    /// Complex or high-value tasks
    /// * Higher reputation required (hk = 5)
    /// * Larger reputation rewards
    /// * Stronger reputation penalties
    Advanced,
    
    /// Mission-critical or high-risk tasks
    /// * Significant reputation required (hk = 7)
    /// * Maximum reputation rewards
    /// * Severe reputation penalties
    Critical,
}

// --- WorkCore Work ---
#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum WorkStatus {
    Created, // Initial state when work is created
    Funded, // Work has been funded by employer
    HashSubmitted, // Initial solution hash submitted
    FullySubmitted, // Complete solution submitted
    ApprovalPending, // Awaiting employer approval
    SubmissionDenied, // Work submission was rejected
    Completed, // Work has been completed and approved
    Refunded, // Funds have been returned to employer
    Closed // Work item is closWed
}

/// Represents a work item in the system
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct Work {
    pub id: felt252, // Unique identifier for the work
    pub employer_address: ContractAddress, // Address of the employer
    pub employer_negotiation_signature: felt252, // Signature from employer negotiation
    pub worker_address: ContractAddress, // Address of the worker
    pub worker_negotiation_signature: felt252, // Signature from worker negotiation
    pub reward: u64, // Amount to be paid upon completion
    pub status: WorkStatus, // Current status of the work item
    pub difficulty: TaskDifficulty // Difficulty of the given task
}