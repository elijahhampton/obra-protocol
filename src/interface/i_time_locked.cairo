/// Interface for managing optional worker time-locked deposits in a crowdsourcing system.
/// Workers can optionally lock deposits after being registered by employers.
///
/// Security Note: Employers may choose to only register workers who are willing to make deposits.
#[starknet::interface]
pub trait ITimeLockedSolutionTrait<TContractState> {
    /// Allows a registered worker to lock a deposit for a work assignment.
    /// This is an optional security feature that workers can provide to demonstrate
    /// commitment to quality and timely delivery. Employers may prefer or require
    /// workers who make deposits during their worker selection process.
    ///
    /// # Arguments
    /// * `work_id` - Unique identifier for the work assignment
    /// * `deadline` - Unix timestamp indicating when the deposit can be claimed back
    ///
    /// # Workflow
    /// * Worker must first be registered by employer through register_worker
    /// * Worker can then choose to lock a deposit to show commitment
    /// * Employers may factor deposit willingness into worker selection
    ///
    /// # Security
    /// * Caller's address is obtained via get_caller_address()
    /// * Only registered workers can lock deposits
    /// * Deposit amount must be sent with the transaction
    /// * Cannot lock a deposit for a work_id that already has a locked deposit
    /// * Deadline must be in the future
    ///
    /// # Errors
    /// * Reverts if work_id doesn't exist
    /// * Reverts if caller is not a registered worker for this work_id
    /// * Reverts if deposit is already locked
    /// * Reverts if deadline is in the past
    /// * Reverts if insufficient funds are sent
    fn time_deposit_lock(ref self: TContractState, work_id: felt252, deadline: u32);

    /// Claims back a locked deposit after the deadline has passed.
    /// Only relevant for workers who chose to make an optional deposit.
    ///
    /// # Arguments
    /// * `work_id` - Unique identifier for the work assignment
    ///
    /// # Workflow
    /// * Only applicable if worker chose to make a deposit
    /// * Successful work completion required for claim
    /// * No action needed if no deposit was made
    ///
    /// # Security
    /// * Caller's address is obtained via get_caller_address()
    /// * Only the original depositor can claim their deposit
    /// * Can only be called after the deadline has passed
    /// * Work must be completed and accepted to claim deposit
    ///
    /// # Errors
    /// * Reverts if work_id doesn't exist
    /// * Reverts if no deposit is locked for this work_id
    /// * Reverts if caller is not the original depositor
    /// * Reverts if deadline has not passed
    /// * Reverts if work is not completed and accepted
    fn time_deposit_claim(ref self: TContractState, work_id: felt252);
}