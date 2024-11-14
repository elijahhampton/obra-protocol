use starknet::ContractAddress;
use crate::interfaces::i_work_core::{IWorkCore, Work, WorkStatus, Decision};

#[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum WorkStatus {
    Created,      // Initial state when work is created
    Funded,       // Work has been funded by employer
    HashSubmitted, // Initial solution hash submitted
    FullySubmitted, // Complete solution submitted
    ApprovalPending, // Awaiting employer approval
    SubmissionDenied, // Work submission was rejected
    Completed,    // Work has been completed and approved
    Refunded,     // Funds have been returned to employer
    Closed        // Work item is closed
}

/// Represents a work item in the system
#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct Work {
    pub id: felt252,                              // Unique identifier for the work
    pub employer_address: ContractAddress,         // Address of the employer
    pub employer_negotiation_signature: felt252,   // Signature from employer negotiation
    pub worker_address: ContractAddress,           // Address of the worker
    pub worker_negotiation_signature: felt252,     // Signature from worker negotiation
    pub reward: u64,                              // Amount to be paid upon completion
    pub status: WorkStatus,                       // Current status of the work item
}

#[starknet::contract]
mod WorkCore {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{IWorkCore, Work, WorkStatus, Decision};
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        payout_token_erc20: ContractAddress,           // Address of ERC20 token used for payments
        works: Map::<felt252, Work>,                   // Mapping of work ID to Work struct
        solution_hashes: Map<felt252, felt252>,        // Mapping of work ID to solution hash
        verification_hashes: Map<felt252, felt252>,    // Mapping of work ID to verification hash
    }

    /// CoNode events covering work creation, worker registration, submission and funding.
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StatusUpdate: StatusUpdate,
        WorkSubmission: WorkSubmission,
        RegisterWork: RegisterWork,
        RegisterWorker: RegisterWorker,
        Funded: Funded,
        SolutionVerified: SolutionVerified
    }

    /// Register a worker 
    #[derive(Drop, starknet::Event)]
    struct RegisterWorker {
        #[key]
        pub id: felt252,
        pub address: ContractAddress,
    }

    /// Update the status of a Work item
    #[derive(Drop, starknet::Event)]
    struct StatusUpdate {
        #[key]
        pub id: felt252,
        pub status: WorkStatus
    }

    /// Notify the hash of a solution
    #[derive(Drop, starknet::Event)]
    struct WorkSubmission {
        id: felt252,
        chain_hash: felt252
    }

    /// Register a work item with an employer and worker
    #[derive(Drop, starknet::Event)]
    struct RegisterWork {
        id: felt252,
        #[key]
        employer_address: ContractAddress,
        worker_address: ContractAddress,

    }

    /// Notify the funding of a work item
    #[derive(Drop, starknet::Event)]
    struct Funded {
        #[key]
        pub work_id: felt252,
        pub amount_funded: u64
    }

    /// Notify the attempt and result to verify a work item
    #[derive(Drop, starknet::Event)]
    struct SolutionVerified {
        #[key]
        pub work_id: felt252,
        pub hash_matches: bool,
    }


    #[constructor]
    fn constructor(ref self: ContractState, payout_token: ContractAddress) {
        self.payout_token_erc20.write(payout_token);
    }

    #[generate_trait]
    impl WorkCoreInternal of WorkCoreInternalTrait {
             /// Validates that a work item exists for the given ID
        /// # Arguments
        /// * `work_id` - The ID of the work item to validate
        /// # Returns
        /// * The Work struct if found, or panics if not found
        fn validate_work(ref self: ContractState, work_id: felt252) -> Work {
            let work = self.works.read(work_id);
            work
        }

        /// Validates that the caller matches the expected address
        /// # Arguments
        /// * `work` - The Work struct to validate against
        /// * `expected` - The expected caller address
        /// # Panics
        /// * If caller does not match expected address
        fn validate_caller(ref self: ContractState, work: Work, expected: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == expected, 'Unauthorized');
        }

        /// Checks if a token transfer can be performed based on allowance and balance
        /// # Arguments
        /// * `token` - The ERC20 token dispatcher
        /// * `owner` - The address of the token owner
        /// * `spender` - The address of the spender
        /// * `amount` - The amount to check
        /// # Returns
        /// * bool indicating if transfer is possible
        /// # Panics
        /// * If insufficient allowance or balance
        fn check_token_requirements(
            ref self: ContractState, 
            token: IERC20Dispatcher,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256
        ) -> bool {
            let allowance = token.allowance(owner, spender);
            let balance = token.balance_of(owner);
            
            // Simple assertions with static messages
            assert(allowance >= amount, 'Insufficient allowance');
            assert(balance >= amount, 'Insufficient balance');

            true
        }
    }

    #[abi(embed_v0)]
    impl WorkCoreImpl of super::IWorkCore<ContractState> {
        
         /// Creates and funds a new work item on the chain
        /// # Arguments
        /// * `work` - The Work struct containing all work details
        /// # Events
        /// * RegisterWork - Emitted when work is registered
        /// * Funded - Emitted when work is funded
        /// * StatusUpdate - Emitted when work status changes
        /// # Panics
        /// * If self-employment is attempted
        /// * If reward is 0
        /// * If token transfer fails
        fn create_work(
            ref self: ContractState, 
            mut work: Work,
        ) {
            // Basic validations
            assert(work.employer_address != work.worker_address, 'Self employment not authorized');
            assert(work.reward > 0, 'Reward must be greater than 0');

            work.employer_address = get_caller_address();
    
            // Convert reward to u256 for token operations
            let reward_u256: u256 = work.reward.into();
    
            // Get payout token dispatcher
            let payout_token_erc20 = IERC20Dispatcher { 
                contract_address: self.payout_token_erc20.read() 
            };
    
            // Check token requirements before proceeding
            let contract_address = get_contract_address();
            let can_transfer = self.check_token_requirements(
                payout_token_erc20,
                work.employer_address,
                contract_address,
                reward_u256
            );
            assert(can_transfer, 'Insufficient tokens/allowance');
    
            let work_id = work.id;
            let mut stored_work = work.clone();
            stored_work.employer_address = contract_address;
            stored_work.status = WorkStatus::Funded;
    
            // Store work first
            self.works.write(work_id, stored_work);
    
            // Attempt to transfer tokens
            let success = payout_token_erc20.transfer_from(
                work.employer_address, 
                contract_address, 
                reward_u256
            );
            assert(success, 'Token transfer failed');
    
            // Emit events for successful creation and funding
            self.emit(Event::RegisterWork(RegisterWork { 
                id: work_id,
                employer_address: work.employer_address,
                worker_address: work.worker_address,
            }));
    
            self.emit(Event::Funded(Funded { 
                work_id, 
                amount_funded: work.reward,
            }));
    
            self.emit(Event::StatusUpdate(StatusUpdate { 
                id: work_id, 
                status: WorkStatus::Funded,
            }));
        }
    
    /// Releases payment to the worker for completed work
        /// # Arguments
        /// * `work_id` - The ID of the completed work
        /// # Events
        /// * StatusUpdate - Emitted when work is closed
        /// # Panics
        /// * If token transfer fails
        fn release_payment(ref self: ContractState, work_id: felt252) {
            let work = self.validate_work(work_id);
            
            let payout_token_erc20 = IERC20Dispatcher { 
                contract_address: self.payout_token_erc20.read() 
            };
    
            // Convert reward to u256 for token operations
            let reward_u256: u256 = work.reward.into();
    
            let success = payout_token_erc20.transfer(
                work.worker_address, 
                reward_u256
            );
            assert(success, 'Token payment failed');
    
            let mut updated_work = work;
            updated_work.status = WorkStatus::Closed;
            self.works.write(work_id, updated_work);
    
            self.emit(Event::StatusUpdate(StatusUpdate { 
                id: work_id, 
                status: WorkStatus::Closed,
            }));
        }

        /// Submits work for verification
        /// # Arguments
        /// * `work_id` - The ID of the work being submitted
        /// * `verification_hash` - Hash of the work for verification
        /// # Events
        /// * WorkSubmission - Emitted when work is submitted
        /// * StatusUpdate - Emitted when status changes
        /// # Panics
        /// * If caller is not the worker
        /// * If work status is invalid
        fn submit(
            ref self: ContractState, 
            work_id: felt252, 
            verification_hash: felt252,
        ) {
            // Validate work exists and caller
            let work = self.validate_work(work_id);
            assert(get_caller_address() == work.worker_address, 'Invalid caller');
            
            // Verify work is in correct state
            assert((work.status == WorkStatus::SubmissionDenied || work.status == WorkStatus::Funded), 'Invalid work status');
            
            // Store verification hash and salt separately
            self.verification_hashes.write(work_id, verification_hash);
    
            // Update work status
            let mut updated_work = work;
            updated_work.status = WorkStatus::ApprovalPending;
            self.works.write(work_id, updated_work);
    
            // Emit events
            self.emit(Event::WorkSubmission(WorkSubmission { 
                id: work_id,
                chain_hash: verification_hash,
            }));
    
            self.emit(Event::StatusUpdate(StatusUpdate { 
                id: work_id, 
                status: WorkStatus::ApprovalPending,
            }));
        }
    
    /// Verifies submitted work and completes the transaction if valid
        /// # Arguments
        /// * `work_id` - The ID of the work to verify
        /// * `solution_hash` - Hash of the solution to verify against
        /// # Returns
        /// * bool indicating if verification was successful
        /// # Events
        /// * SolutionVerified - Emitted with verification result
        /// * StatusUpdate - Emitted when status changes
        /// # Panics
        /// * If work status is not ApprovalPending
        fn verify_and_complete(
            ref self: ContractState,
            work_id: felt252,
            solution_hash: felt252,
        ) -> bool {
            // Validate work and caller
            let work = self.validate_work(work_id);
            
            // Verify work is in correct state
            assert(work.status == WorkStatus::ApprovalPending, 'Invalid work status');
            
            // Get stored verification data
            let stored_verification_hash = self.verification_hashes.read(work_id);
            
            // Compute hash of provided solution and salt
            
            let hash_matches = stored_verification_hash == solution_hash;
            
            // Prevent timing attacks by always executing both paths
            let mut updated_work = work;
            if hash_matches {
                updated_work.status = WorkStatus::Completed;
                self.release_payment(work_id);
            } else {
                updated_work.status = WorkStatus::SubmissionDenied;
            }
    
            // Store updated work
            self.works.write(work_id, updated_work.clone());
    
            // Emit events
            self.emit(Event::SolutionVerified(SolutionVerified {
                work_id,
                hash_matches,
            }));
    
            self.emit(Event::StatusUpdate(StatusUpdate { 
                id: work_id, 
                status: updated_work.status,
            }));
    
            hash_matches
        }
       
    }
}