#[starknet::contract]
pub mod Core {
    use crate::interface::i_core::{ICore, Task, TaskStatus};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::Map;
    use core::num::traits::Zero;
    use core::zeroable::NonZero;
    use core::option::Option;
    use crate::core::event::{
       StatusUpdate, ProviderRegistered, TaskRegistered, WorkSubmission,
    };

    #[storage]
    struct Storage {
        /// Mapping of user contract addresses to registration status
        registrar: Map<ContractAddress, bool>,
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
    }

    #[constructor]
    fn constructor(ref self: ContractState, payout_token: ContractAddress) {
        self.payout_token_erc20.write(payout_token);
    }

    #[generate_trait]
    impl CoreInternal of CoreInternalTrait {
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

            task.status = Option::Some(TaskStatus::Closed);
            self.tasks.write(task_id.into(), task);

            self
                .emit(
                    Event::StatusUpdate(StatusUpdate { id: task_id, status: TaskStatus::Closed }),
                );
        }
    }

    #[abi(embed_v0)]
    impl WorkCoreImpl of ICore<ContractState> {
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
            task.status = Option::Some(TaskStatus::Created);
            self.tasks.write(task.id.into(), task.clone());

            if task.provider.is_non_zero() {
                self.assign_task(task.id, task.provider);
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

        }

                /// Assigns a provider to a task given a task_id.
                fn assign_task(ref self: ContractState, task_id: NonZero<felt252>, provider: ContractAddress) {
                    assert!(!provider.is_zero(), "must assign task to a provider");
        
                    let mut task = self.tasks.read(task_id.into());
                    assert!(
                        task.status.unwrap() != TaskStatus::Occupied && task.provider.is_zero(),
                        "task previously occupied",
                    );
        
                    let non_zero_task_id = task.id.clone();
                    task.provider = provider;
                    task.status = Option::Some(TaskStatus::Occupied);
                    self.tasks.write(task.id.into(), task);
                    self
                        .emit(
                            Event::ProviderRegistered(
                                ProviderRegistered { id: non_zero_task_id, address: provider },
                            ),
                        );
                }
        

                /// Returns the task with the given task_id.
                fn get_task(ref self: ContractState, task_id: NonZero<felt252>) -> Task {
                    self.tasks.read(task_id.into())
                }


        /// Submits a verification hash for a solution for a task_id.
        fn finalize_task(
            ref self: ContractState, task_id: NonZero<felt252>, verification_hash: NonZero<felt252>,
        ) {
            let mut task = self.tasks.read(task_id.into());

            assert(get_caller_address() == task.provider, 'Unauthorized caller');
            assert(
                (task.status.unwrap() == TaskStatus::SubmissionDenied
                    || task.status.unwrap() == TaskStatus::Occupied),
                'Invalid task status',
            );

            task.status = Option::Some(TaskStatus::ApprovalPending);

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
                        StatusUpdate { id: task_id, status: TaskStatus::ApprovalPending },
                    ),
                );
        }
    }
}
