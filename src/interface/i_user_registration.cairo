// interfaces/i_user_registration.cairo

#[starknet::interface]
#[derive(Serde)]
pub trait IUserRegistration<TContractState> {
    /// Registers a new user in the system, creating their initial profile and statistics.
    /// This is called automatically by create_work() and submit() if the user doesn't exist.
    ///
    /// # Details
    /// * Creates new user profile with 0 initial reputation
    /// * Initializes empty task history
    /// * Sets up category-specific performance tracking
    /// * Establishes activity metrics
    ///
    /// # Security
    /// * One profile per address
    /// * Cannot be used to reset existing profiles
    /// * Automatic registration ensures consistent user state
    ///
    /// # Errors
    /// * Reverts if user already exists and tries to register again
    fn register(ref self: TContractState);
}
