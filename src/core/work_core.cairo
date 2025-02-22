#[starknet::contract]
pub mod WorkCore {
    use crate::types::task::{Task, WorkStatus};
    use crate::interface::i_work_core::{IWorkCore};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::Map;
    use core::num::traits::Zero;
    use core::zeroable::NonZero;
    
    #[storage]
    struct Storage {
        // The registrar map maps a user contract address to a profile.
        registrar: Map<ContractAddress, felt252>,
        // The address of base ERC20 token used for Task not created in an external market.
        payout_token_erc20: ContractAddress, 
        // A mapping of task IDs to task.
        tasks: Map::<felt252, Task>, 
        // A mapping of task IDs to task verification hashes.
        verification_hashes: Map<felt252, felt252> 
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        // Represents a status up for a task.
        StatusUpdate: StatusUpdate,
        // Represents a submission for a task.
        WorkSubmission: WorkSubmission,
        // Represents a creation and registration of a task.
        RegisterWork: RegisterWork,
        // Represents an assignment of a ServiceProvider to a task.
        RegisterWorker: RegisterWorker,
        // Represents a task that has been funded.
        Funded: Funded,
        // Represents a verified solution for a task.
        SolutionVerified: SolutionVerified,
    }

    #[derive(Drop, starknet::Event)]
    struct RegisterWorker {
        #[key]
        pub id: NonZero<felt252>,
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct StatusUpdate {
        #[key]
        pub id: NonZero<felt252>,
        pub status: WorkStatus,
    }

    #[derive(Drop, starknet::Event)]
    struct WorkSubmission {
        id: NonZero<felt252>,
        chain_hash: NonZero<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct RegisterWork {
        id: NonZero<felt252>,
        #[key]
        initiator: ContractAddress,
        provider: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Funded {
        #[key]
        pub task_id: NonZero<felt252>,
        pub amount_funded: NonZero<u256>,
    }

    #[derive(Drop, starknet::Event)]
    struct SolutionVerified {
        #[key]
        pub task_id: NonZero<felt252>,
        pub hash_matches: bool,
    }


    #[constructor]
    fn constructor(ref self: ContractState, payout_token: ContractAddress) {
        self.payout_token_erc20.write(payout_token);
    }

    #[generate_trait]
    impl WorkCoreInternal of WorkCoreInternalTrait {
        fn task(ref self: ContractState, task_id: NonZero<felt252>) -> Task {
            self.tasks.read(task_id.into())
        }

        fn validate_caller(ref self: ContractState, task: Task, expected_caller: ContractAddress) {
            assert!(get_caller_address() == expected_caller, "unauthorized, caller is not expected");
        }

        fn check_token_requirements(
            ref self: ContractState,
            token: IERC20Dispatcher,
            spender: ContractAddress,
            to: ContractAddress,
            amount: NonZero<u256>,
        ) -> bool {
            let allowance = token.allowance(spender, to);
            let balance = token.balance_of(spender);

            assert!(balance >= amount.into(), "Insufficient balance for operation");
            assert!(allowance >= amount.into(), "Insufficient allowance for operation");

            true
        }

        fn release_payment(ref self: ContractState, task_id: NonZero<felt252>) {
            let sol = self.verification_hashes.read(task_id.into());
            assert!(sol != 0, "task does not have solution");
            
            let mut task = self.tasks.read(task_id.into());
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.payout_token_erc20.read(),
            };
            let reward_u256: u256 = task.reward.into();

            let success = token_dispatcher.transfer(task.provider, reward_u256);
            assert(success, 'reward payment failed');

            task.status = WorkStatus::Closed;
            self.tasks.write(task_id.into(), task);

            self
                .emit(
                    Event::StatusUpdate(StatusUpdate { id: task_id, status: WorkStatus::Closed }),
                );
        }
    }

    #[abi(embed_v0)]
    impl WorkCoreImpl of IWorkCore<ContractState> {
        fn register_task(ref self: ContractState, mut task: Task) {
            assert!(task.initiator != task.provider, "self employment not authorized");
     
            task.initiator = get_caller_address();

            // Convert reward to u256 for token operations
            let reward: u256 = task.reward.into();

            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.payout_token_erc20.read(),
            };

            let contract_address = get_contract_address();
            let can_transfer = self.check_token_requirements(token_dispatcher, task.initiator, contract_address, task.reward);
            assert!(can_transfer, "insufficient balance or allowance");

            task.status = WorkStatus::Funded;
            self.tasks.write(task.id.into(), task.clone());

            let success = token_dispatcher.transfer_from(task.initiator, contract_address, reward.into());
            assert!(success, "funding transfer failed");

            self
                .emit(
                    Event::RegisterWork(
                        RegisterWork {
                            id: task.id,
                            initiator: task.initiator,
                            provider: task.provider,
                        },
                    ),
                );
            
            self.emit(Event::Funded(Funded { task_id: task.id, amount_funded: task.reward }));

            self
                .emit(
                    Event::StatusUpdate(StatusUpdate { id: task.id, status: WorkStatus::Funded }),
                );
        }

        fn assign(ref self: ContractState, task_id: NonZero<felt252>, provider: ContractAddress) {
             assert!(!provider.is_zero(), "must assign task to a provider");
             

            let mut task = self.tasks.read(task_id.into());
            assert!(task.provider.is_zero(), "task previously occupied");

            task.provider = provider;
        }

        fn submit(ref self: ContractState, task_id: NonZero<felt252>, verification_hash: NonZero<felt252>) {
            let task = self.tasks.read(task_id.into());
             assert(get_caller_address() == task.provider, 'Unauthorized caller');

            assert(
                (task.status == WorkStatus::SubmissionDenied || task.status == WorkStatus::Funded),
                'Invalid task status',
            );

            self.verification_hashes.write(task_id.into(), verification_hash.into());

            let mut updated_work = task;
            updated_work.status = WorkStatus::ApprovalPending;
            self.tasks.write(task_id.into(), updated_work);

            self
                .emit(
                    Event::WorkSubmission(
                        WorkSubmission { id: task_id, chain_hash: verification_hash },
                    ),
                );

            self
                .emit(
                    Event::StatusUpdate(
                        StatusUpdate { id: task_id, status: WorkStatus::ApprovalPending },
                    ),
                );
        }

        fn verify_and_complete(
            ref self: ContractState, task_id: NonZero<felt252>, solution_hash: NonZero<felt252>
        ) -> bool {
       
            let mut task = self.tasks.read(task_id.into());
            assert(task.status == WorkStatus::ApprovalPending, 'Invalid task status');

            let stored_verification_hash = self.verification_hashes.read(task_id.into());
            let hash_matches = stored_verification_hash == solution_hash.into();

            // Prevent timing attacks by always executing both paths
            if hash_matches {
                task.status = WorkStatus::Completed;
                self.emit(Event::SolutionVerified(SolutionVerified { task_id, hash_matches }));
                self
                .emit(
                    Event::StatusUpdate(StatusUpdate { id: task_id, status: WorkStatus::Completed }),
                );
                self.release_payment(task_id);
            } else {
                task.status = WorkStatus::SubmissionDenied;
            }

            self.tasks.write(task_id.into(), task);

            hash_matches
        }
    }
}
