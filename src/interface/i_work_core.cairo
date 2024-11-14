// interfaces/i_work_core.cairo

/// Interface defining the core functionality for managing work items in the contract
/// This interface provides methods for creating, submitting, verifying and completing work assignments,
/// as well as handling payments between employers and workers
#[starknet::interface]
pub trait IWorkCore<TContractState> {
    /// Creates and funds a new work item on the chain
    /// # Arguments
    /// * `work` - Work struct containing:
    ///   - id: Unique identifier for the work
    ///   - employer_address: Address of the employer
    ///   - employer_negotiation_signature: Signature from employer negotiation
    ///   - worker_address: Address of the assigned worker
    ///   - worker_negotiation_signature: Signature from worker negotiation
    ///   - reward: Amount to be paid upon completion
    ///   - status: Current status of the work item
    /// # Events
    /// * RegisterWork - When work is successfully registered
    /// * Funded - When work is successfully funded
    /// * StatusUpdate - When work status changes to Funded
    /// # Panics
    /// * If self-employment is attempted
    /// * If reward amount is 0
    /// * If token transfer or allowance checks fail
    fn create_work(ref self: TContractState, work: Work);

    /// Verifies submitted work against the stored verification hash and completes the transaction if valid
    /// # Arguments
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
        ref self: TContractState,
        work_id: felt252,
        solution_hash: felt252,
    ) -> bool;

    /// Submits completed work for verification by providing a verification hash
    /// # Arguments
    /// * `work_id` - The unique identifier of the work being submitted
    /// * `verification_hash` - Hash of the completed work for verification
    /// # Events
    /// * WorkSubmission - When work is submitted with verification hash
    /// * StatusUpdate - Updates work status to ApprovalPending
    /// # Panics
    /// * If caller is not the assigned worker
    /// * If work status is not Funded or SubmissionDenied
    fn submit(
        ref self: TContractState, 
        work_id: felt252, 
        verification_hash: felt252,
    );

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