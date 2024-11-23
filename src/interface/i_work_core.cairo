// interfaces/i_work_core.cairo
use starknet::ContractAddress;
use crate::types::task::{Work};

/// Interface defining the core functionality for managing work items in the contract
/// This interface provides methods for creating, submitting, verifying and completing work
/// assignments, as well as handling payments between employers and workers
#[starknet::interface]
pub trait IWorkCore<TContractState> {
    /// Creates and funds a new work item on the chain. Will automatically register
    /// the caller if they don't already exist in the system.
    ///
    /// # Arguments
    /// * `work` - The Work struct containing all work details
    ///
    /// # Auto-Registration
    /// * Checks if caller exists in system
    /// * If not, automatically calls register()
    /// * Creates new profile with 0 initial reputation
    ///
    /// # Events
    /// * RegisterWork - Emitted when work is registered
    /// * Funded - Emitted when work is funded
    /// * StatusUpdate - Emitted when work status changes
    /// * UserRegistered - Emitted if new user is registered
    ///
    /// # Panics
    /// * If self-employment is attempted
    /// * If reward is 0
    /// * If token transfer fails
    fn create_work(ref self: TContractState, work: Work);

    /// Verifies submitted work against the stored verification hash and completes the transaction
    /// if valid # Arguments
    /// * `work_id` - The unique identifier of the work to verify
    /// * `solution_hash` - The hash of the solution to verify against stored verification hash
    /// # Returns
    /// * `bool` - true if verification successful, false otherwise
    /// # Events
    /// * SolutionVerified - Indicates verification result
    /// * StatusUpdate - Updates work status to either Completed or SubmissionDenied
    /// # Panics
    /// * If work is not in ApprovalPending status
    fn verify_and_complete(
        ref self: TContractState, work_id: felt252, solution_hash: felt252, evaluation: u32
    ) -> bool;

    /// Submits work for verification. Will automatically register the caller
    /// if they don't already exist in the system.
    ///
    /// # Arguments
    /// * `work_id` - The ID of the work being submitted
    /// * `verification_hash` - Hash of the work for verification
    ///
    /// # Auto-Registration
    /// * Checks if caller exists in system
    /// * If not, automatically calls register()
    /// * Creates new profile with 0 initial reputation
    ///
    /// # Events
    /// * WorkSubmission - Emitted when work is submitted
    /// * StatusUpdate - Emitted when status changes
    /// * UserRegistered - Emitted if new user is registered
    ///
    /// # Panics
    /// * If caller is not the worker
    /// * If work status is invalid
    fn submit(ref self: TContractState, work_id: felt252, verification_hash: felt252,);

    /// Releases the escrowed payment to the worker after successful work completion
    /// # Arguments
    /// * `work_id` - The unique identifier of the completed work
    /// # Events
    /// * StatusUpdate - Updates work status to Closed
    /// # Panics
    /// * If work doesn't exist
    /// * If token transfer fails
    fn release_payment(ref self: TContractState, work_id: felt252);
}

