use starknet::ContractAddress;

/// Configuration for market payment handling
#[derive(Drop, Serde, starknet::Store)]
struct PaymentConfig {
   /// Percentage fee taken by market (basis points)
   fee_percentage: u256,
   /// Whether payments auto-release after timeout
   auto_release: bool,
   /// Time until auto-release (in seconds)
   release_timeout: u64,
   /// Freeze payments during active disputes
   dispute_lock: bool
}

#[starknet::interface]
pub trait IMarketPayment<TContractState> {
   /// Get market's payment configuration
   /// # Returns
   /// * `PaymentConfig` - Market's payment settings
   fn get_payment_config(ref self: TContractState) -> PaymentConfig;

   /// Get payment distribution instructions
   /// # Arguments
   /// * `payment_id` - ID of payment to distribute
   /// # Returns
   /// * Array of (address, amount) tuples for distribution
   fn get_payment_splits(ref self: TContractState, payment_id: u256) -> Array<(ContractAddress, u256)>;

   /// Returns true if market supports custom payment handling
   fn supports_custom_payments(ref self: TContractState) -> bool;
}