use starknet::ContractAddress;
use crate::types::dispute::{Dispute};

// User                    WorkCore                    Market
// |                         |                          |
// |   create_dispute()      |                          |
// |-----------------------> |                          |
// |                         |                          |
// |                         |  notify_dispute_created()|
// |                         |------------------------->|
// |                         |                          |
// |                         |                          |
// |                         |      handle_dispute()    |
// |                         |      (internal)          |
// |                         |                          |
// |                         |    resolve_dispute()     |
// |                         |<-------------------------|
// |                         |                          |
// |     get_dispute()       |                          |
// |<----------------------- |                          |
// |                         |                          |

/// Kleros Example 
// User              WorkCore            Market (Kleros)         Court
// |                   |                     |                    |
// |  create_dispute() |                     |                    |
// |------------------>|                     |                    |
// |                   |                     |                    |
// |                   | notify_dispute()    |                    |
// |                   |-------------------->|                    |  
// |                   |                     |                    |
// |                   |                     | Create Case        |
// |                   |                     |------------------->|
// |                   |                     |                    |
// |                   |                     | Draw Jurors        |
// |                   |                     |<-------------------|
// |                   |                     |                    |
// |                   |                     | Evidence Period    |
// |                   |                     |<------------------>|
// |                   |                     |                    |
// |                   |                     | Voting Period      |
// |                   |                     |<------------------>|
// |                   |                     |                    |
// |                   |                     | Appeal Period      |
// |                   |                     |<------------------>|
// |                   |                     |                    |
// |                   |                     | Final Decision     |
// |                   |                     |<-------------------|
// |                   |                     |                    |
// |                   |  resolve_dispute()  |                    |
// |                   |<--------------------|                    |
// |                   |                     |                    |
// |  get_dispute()    |                     |                    |
// |<------------------|                     |                    |


/// Payments and Distribution
// WorkCore Distributes with Market Input
// ------------------------

// User         WorkCore            Market           Recipients
// |              |                 |                  |
// | submit_work  |                 |                  |
// |------------->|                 |                  |
// |              |                 |                  |
// |              | get_distribution|                  |
// |              |---------------->|                  |
// |              | return splits   |                  |
// |              |<----------------|                  |
// |              |                 |                  |
// |              | transfer_funds  |                  |
// |              |----------------------------------> |

/// Implemented by work_core
#[starknet::interface]
pub trait IMarketCoreTrait<TContractState> {
   /// Notifies market that a dispute has been created. Called by work_core.
   /// # Arguments
   /// * `dispute_id` - Unique identifier of the created dispute
   fn notify_dispute_created(ref self: TContractState, dispute_id: u256);

   /// Retrieves dispute details
   /// # Arguments 
   /// * `dispute_id` - ID of dispute to fetch
   /// # Returns
   /// * `Dispute` - Full dispute details including status and participants
   fn get_dispute(self: @TContractState, dispute_id: u256) -> Dispute;

  /// Get all disputes created by a specific address
   /// # Arguments
   /// * `address` - Address to query disputes for
   /// # Returns
   /// * Array of dispute IDs where address is creator
   fn get_disputes_created_by(ref self: TContractState, address: ContractAddress) -> Array<u256>;

   /// Get all disputes where address is involved (as creator or respondent)
   /// # Arguments
   /// * `address` - Address to query disputes for  
   /// # Returns
   /// * Array of dispute IDs where address is a participant
   fn get_disputes_involved_in(ref self: TContractState, address: ContractAddress) -> Array<u256>;
}

