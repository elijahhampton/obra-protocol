use starknet::ContractAddress;
use crate::types::dispute::{DisputeConfig, Dispute, DisputeStatus};

#[starknet::interface]
pub trait IMarket<TContractState> {
    /// Returns true if market implements dispute resolution
   fn supports_disputes(self: @TContractState) -> bool;
   
   /// Internal market-specific dispute resolution logic
   /// # Arguments
   /// * `dispute_id` - ID of dispute to handle
   fn handle_dispute(ref self: TContractState, dispute_id: u256);

   /// Resolves dispute in work_core. Called by market implementation.
   /// # Arguments
   /// * `dispute_id` - ID of dispute to resolve
   /// * `winner` - Address of the winning party
   fn resolve_dispute(ref self: TContractState, dispute_id: u256, winner: ContractAddress);

    /// Gets current dispute status without full dispute details
   /// # Arguments
   /// * `dispute_id` - ID of dispute to check
   /// # Returns
   /// * `DisputeStatus` - Current status of the dispute
   fn get_dispute_status(self: @TContractState, dispute_id: u256) -> DisputeStatus;

   /// Returns dispute configuration including timeouts and parameters
   /// # Returns
   /// * `DisputeConfig` - Contains resolution_timeout and other settings
   fn get_dispute_config(self: @TContractState) -> DisputeConfig;
}