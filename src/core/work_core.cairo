#[starknet::contract]
pub mod WorkCore {
    use super::super::error::RegistrationError;
    use crate::types::task::{Task, WorkStatus};
    use crate::interface::i_work_core::{IWorkCore};
    use crate::interface::i_user_registration::{IUserRegistration};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::Map;
    use core::num::traits::Zero;
    use core::zeroable::NonZero;
    use core::result::Result;
    use core::option::Option;
    use crate::core::event::{
        SolutionVerified, StatusUpdate, ProviderRegistered, TaskRegistered, WorkSubmission,
    };

    #[storage]
    struct Storage {
        /// Mapping of user contract addresses to registration status
        registrar: Map<ContractAddress, bool>,
        /// Task mapped by contract address and task id
        profile_tasks: Map<(ContractAddress, felt252), Task>,
        /// Task ordered by creation and mapped by contract address and index
        profile_tasks_ordered: Map<(ContractAddress, u32), felt252>,
        /// Maps a contract address to the total number of task completed
        profile_task_count: Map<ContractAddress, u32>,
        /// The default ERC20 reward token
        payout_token_erc20: ContractAddress,
        /// A map of task by id
        tasks: Map::<felt252, Task>,
        /// Task solution hashes mapped by task id
        verification_hashes: Map<felt252, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        // Represents a status up for a task.
        StatusUpdate: StatusUpdate,
        // Represents a submission for a task.
        WorkSubmission: WorkSubmission,
        // Represents a creation and registration of a task.
        TaskRegistered: TaskRegistered,
        // Represents an assignment of a ServiceProvider to a task.
        ProviderRegistered: ProviderRegistered,
        // Represents a verified solution for a task.
        SolutionVerified: SolutionVerified,
    }

    #[constructor]
    fn constructor(ref self: ContractState, payout_token: ContractAddress) {
        self.payout_token_erc20.write(payout_token);
    }

    #[generate_trait]
    impl WorkCoreInternal of WorkCoreInternalTrait {
        /// Returns the task with the given task_id.
        fn task(ref self: ContractState, task_id: NonZero<felt252>) -> Task {
            self.tasks.read(task_id.into())
        }

        /// Validates an expected caller.
        fn validate_caller(ref self: ContractState, task: Task, expected_caller: ContractAddress) {
            assert!(
                get_caller_address() == expected_caller, "unauthorized, caller is not expected",
            );
        }

        /// Checks for a given payment if:
        /// - The spender has the balance to spend
        /// - The spender has allocated an allowance greater than or equal to the
        /// amount
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

        /// Releases a payment to the provider of a Task.
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

            task.status = Option::Some(WorkStatus::Closed);
            self.tasks.write(task_id.into(), task);

            self
                .emit(
                    Event::StatusUpdate(StatusUpdate { id: task_id, status: WorkStatus::Closed }),
                );
        }
    }

    #[abi(embed_v0)]
    impl UserRegistrationImpl of IUserRegistration<ContractState> {
        /// Registers the function caller.
        fn register(ref self: ContractState) -> Result<(), RegistrationError> {
            let caller = get_caller_address();

            if self.profile(caller) {
                return Result::Err(RegistrationError::AlreadyRegistered);
            }

            self.registrar.write(caller, true);

            Result::Ok(())
        }

        /// Returns the registration status of a given address.
        fn profile(ref self: ContractState, address: ContractAddress) -> bool {
            let is_registered = self.registrar.read(address);
            is_registered
        }
    }

    #[abi(embed_v0)]
    impl WorkCoreImpl of IWorkCore<ContractState> {
        /// Registers a task 
        fn register_task(ref self: ContractState, mut task: Task) {
            assert!(task.initiator != task.provider, "self employment not authorized");
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.payout_token_erc20.read(),
            };

            let contract_address = get_contract_address();

            let can_transfer = self
                .check_token_requirements(
                    token_dispatcher, get_caller_address(), contract_address, task.reward,
                );
            assert!(can_transfer, "insufficient balance or allowance");
            let success = token_dispatcher
                .transfer_from(task.initiator, contract_address, task.reward.into());
            assert!(success, "funding transfer failed");

            let caller = get_caller_address();
            task.initiator = caller;
            task.status = Option::Some(WorkStatus::Created);
            self.tasks.write(task.id.into(), task.clone());
            self.profile_tasks.write((caller, task.id.into().clone()), task.clone());

            let current_count = self.profile_task_count.read(caller);
            self.profile_tasks_ordered.write((caller, current_count), task.id.into());
            self.profile_task_count.write(caller, current_count + 1);

            if task.provider.is_non_zero() {
                self.assign(task.id, task.provider);
            }

            self
                .emit(
                    Event::TaskRegistered(
                        TaskRegistered {
                            id: task.id,
                            initiator: task.initiator,
                            provider: task.provider,
                            amount_funded: task.reward.into(),
                        },
                    ),
                );

            if task.provider.is_non_zero() {
                self
                .emit(
                    Event::ProviderRegistered(
                        ProviderRegistered { id: task.id.into(), address: task.provider },
                    ),
                );
            }
        }

        /// Returns an array of task regardless of status given a contract address.
        fn get_tasks(ref self: ContractState, address: ContractAddress) -> Array<Task> {
            let count = self.profile_task_count.read(address);
            let mut tasks = ArrayTrait::new();
            let mut i: u32 = 0;

            loop {
                if i >= count {
                    break;
                }

                let task_id = self.profile_tasks_ordered.read((address, i));
                let task = self.profile_tasks.read((address, task_id));
                tasks.append(task);
                i += 1;
            };
            tasks
        }   

        /// Assigns a provider to a task given a task_id.
        fn assign(ref self: ContractState, task_id: NonZero<felt252>, provider: ContractAddress) {
            assert!(!provider.is_zero(), "must assign task to a provider");

            let mut task = self.tasks.read(task_id.into());
            assert!(
                task.status.unwrap() != WorkStatus::Occupied && task.provider.is_zero(),
                "task previously occupied",
            );

            let non_zero_task_id = task.id.clone();
            task.provider = provider;
            task.status = Option::Some(WorkStatus::Occupied);
            self.tasks.write(task.id.into(), task);
            self
                .emit(
                    Event::ProviderRegistered(
                        ProviderRegistered { id: non_zero_task_id, address: provider },
                    ),
                );
        }

        /// Submits a verification hash for a solution for a task_id.
        fn submit(
            ref self: ContractState, task_id: NonZero<felt252>, verification_hash: NonZero<felt252>,
        ) {
            let mut task = self.tasks.read(task_id.into());

            assert(get_caller_address() == task.provider, 'Unauthorized caller');
            assert(
                (task.status.unwrap() == WorkStatus::SubmissionDenied
                    || task.status.unwrap() == WorkStatus::Occupied),
                'Invalid task status',
            );

            task.status = Option::Some(WorkStatus::ApprovalPending);

            self.verification_hashes.write(task_id.into(), verification_hash.into());
            self.tasks.write(task_id.into(), task);

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

        /// Verifies a verification hash matches a solution hash and marks a Task as complete.
        fn verify_and_complete(
            ref self: ContractState, task_id: NonZero<felt252>, solution_hash: NonZero<felt252>,
        ) -> bool {
            let task_id_felt: felt252 = task_id.into();
            let mut task = self.tasks.read(task_id.into());

            assert(task.status == Option::Some(WorkStatus::ApprovalPending), 'Invalid task status');

            let stored_verification_hash = self.verification_hashes.read(task_id_felt);
            let hash_matches = stored_verification_hash == solution_hash.into();

            // Update state based on verification. We maintain both paths of execution to
            // prevent timing attacks
            if hash_matches {
                task.status = Option::Some(WorkStatus::Completed);
                self.emit(Event::SolutionVerified(SolutionVerified { task_id, hash_matches }));
                self
                    .emit(
                        Event::StatusUpdate(
                            StatusUpdate { id: task_id, status: WorkStatus::Completed },
                        ),
                    );
                self.release_payment(task_id);
            } else {
                task.status = Option::Some(WorkStatus::SubmissionDenied);
                self.tasks.write(task_id_felt, task.clone());
            }

            hash_matches
        }
    }
}
