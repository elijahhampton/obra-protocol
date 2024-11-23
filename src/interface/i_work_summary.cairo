use starknet::ContractAddress;

/// An interface representing the UserSummary contract which stores personal statistics,
/// and task history for requesters and workers.
#[starknet::interface]
pub trait IUserSummaryTrait<TContractState> {
    /// Returns the reputation value (βW) for a given address. Reputation is an integer
    /// that reflects user's past performance. All users start at 0 and gain/lose reputation 
    /// based on task completion quality and difficulty.
    ///
    /// # Arguments
    /// * `address` - Contract address of the worker or requester
    ///
    /// # Reputation System
    /// Task difficulties determine reputation thresholds (hk) and rewards:
    /// * Beginner:  hk = 0  - Entry level, minimal rewards/penalties
    /// * Basic:     hk = 3  - Standard tasks and rewards
    /// * Advanced:  hk = 5  - Higher stakes and rewards
    /// * Critical:  hk = 7  - Maximum stakes and rewards
    ///
    /// # Reputation Calculation
    /// Reputation βW updates based on task difficulty and evaluation 'a':
    /// * If a = H (high effort) and βW ≥ difficulty.hk():
    ///     βW + difficulty.reward_points()
    /// * If a = L (low effort) and βW ≥ difficulty.hk() + 1:
    ///     βW - difficulty.penalty_points()
    /// * If a = L and βW = difficulty.hk():
    ///     0 (reputation reset)
    /// * If βW < difficulty.hk() + 1:
    ///     βW + 1 (encouragement for newer users)
    ///
    /// # Task Access
    /// * Users can always access Beginner tasks
    /// * Higher difficulties require matching reputation thresholds
    /// * Failing at threshold level resets reputation to 0
    /// * Consistent good performance needed to maintain high reputation
    ///
    /// # Security  
    /// * Cannot be directly modified by users
    /// * Updates only through task completion
    /// * Reputation reset prevents "coasting" on past performance
    /// * Higher difficulties have higher stakes
    ///
    /// # Returns
    /// * Current reputation value for the address
    /// * Returns 0 if address not registered
    fn rep(ref self: TContractState, address: ContractAddress) -> u32;

    /// Increase reputation based on the calculated amount
    fn incr_rep(ref self: TContractState, address: ContractAddress, amount: u32);

    /// Decreases reputation based on the calculated amount
    fn decr_rep(ref self: TContractState, address: ContractAddress, amount: u32);

    /// Returns the list of tasks associated with an address, including:
    /// For workers: total receiving task lists and high evaluation task list (ε, φ)
    /// For requesters: posted tasks and their current status
    ///
    /// # Arguments
    /// * `address` - Contract address of the worker or requester
    ///
    /// # Reliability Calculation
    /// For each task category k:
    /// * εk = number of tasks received in category k
    /// * φk = number of high evaluation tasks in category k
    /// * Reliability (relk) = εk/φk
    /// This measures topic expertise in specific categories.
    ///
    /// # Notes
    /// * Tracks category-specific performance (categoryk(εk, φk))
    /// * Shows task status (Pending, Unclaimed, Claimed, etc.)
    /// * Contains pointers to RWRC contracts
    /// * Updates automatically with task completion
    ///
    /// # Errors
    /// * Reverts if address doesn't have a summary
    fn task_list(ref self: TContractState, address: ContractAddress);

    /// Creates a new user summary when a user registers through URC.
    /// Initializes profile, reputation, task lists, and activity metrics.
    ///
    /// # Notes
    /// * Created automatically during user registration
    /// * Initializes:
    ///   - Profile (skills, profession)
    ///   - Initial reputation value (set to average)
    ///   - Empty task lists (εk = 0, φk = 0 for all categories)
    ///   - Activity metrics
    ///
    /// # Security
    /// * Can only be called by the URC contract
    /// * One summary per address
    ///
    /// # Errors
    /// * Reverts if summary already exists
    /// * Reverts if not called by URC
    fn create_summary(ref self: TContractState);

    /// Verifies if a worker meets the minimum requirements for a task based on
    /// reputation (βW) and reliability values (relk).
    ///
    /// # Requirements Check
    /// * Reputation check: worker's βW ≥ required reputation threshold
    /// * Reliability check: worker's relk ≥ required reliability threshold
    /// * Category expertise: εk and φk values meet minimum requirements
    ///
    /// # Notes
    /// * Each category k maintains separate (εk, φk) pairs
    /// * Higher reliability indicates more expertise in category
    /// * All values updated only through completed tasks
    ///
    /// # Security
    /// * Values cannot be manipulated by users
    /// * Updates only through completed tasks
    ///
    /// # Errors
    /// * Reverts if worker doesn't meet minimum requirements
    /// * Reverts if worker summary doesn't exist
    fn check_worker_qualification(ref self: TContractState);
}
