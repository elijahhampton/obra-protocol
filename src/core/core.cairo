#[starknet::contract]
pub mod Core {
use starknet::storage::StoragePathEntry;
use starknet::storage::VecTrait;
use crate::interface::i_core::{
        ICore, ICoreMarket, IExternalEscrow, ICoreFeeManagement, Task, TaskState,
    };
    use crate::interface::i_market::{Market};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::Map;
    use core::num::traits::Zero;
    use core::zeroable::NonZero;
    use core::option::Option;
    use starknet::storage::Vec;
    use starknet::storage::MutableVecTrait;
    use crate::core::event::{StatusUpdate, NewProviderRegistrarEntry, ProviderRegistered, TaskRegistered, WorkSubmission};
use core::array::Array;
use core::array::ArrayTrait;

    #[storage]
    struct Storage {
        /// Mapping of user contract addresses to registration status
        provider_registrar: Map<ContractAddress, bool>,
        /// Mapping of market contract addresses to (market_type, registration_status)
        market_registrar: Map<ContractAddress, bool>,
        /// A list of registered markets
        market_list: Vec<Market>,
        /// The default ERC20 reward token
        payout_token_erc20: ContractAddress,
        /// A map of task by id
        tasks: Map::<felt252, Task>,
        /// Task solution hashes mapped by task id
        verification_hashes: Map<felt252, felt252>,
        /// The task registration fee percentage
        task_registration_fee_percentage: u8,
        // The market distribution reward percentage
        market_distribution_reward_percentage: u8,
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
        // Represents a new entry to the provider registry
        NewProviderRegistarEntry: NewProviderRegistrarEntry
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        payout_token: ContractAddress,
        initial_task_registration_fee_percentage: u8,
        initial_market_distribution_reward_percentage: u8,
    ) {
        self.payout_token_erc20.write(payout_token);
        self.task_registration_fee_percentage.write(initial_task_registration_fee_percentage);
        self
            .market_distribution_reward_percentage
            .write(initial_market_distribution_reward_percentage);
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
            amount: u64,
        ) -> bool {
            let allowance = token.allowance(spender, to);
            let balance = token.balance_of(spender);

            assert!(balance >= amount.into(), "Insufficient balance for operation");
            assert!(allowance >= amount.into(), "Insufficient allowance for operation");

            true
        }

        /// Releases a payment to the provider of a Task.
        fn release_payment(ref self: ContractState, task_id: u64) {
            let sol = self.verification_hashes.read(task_id.into());
            assert!(sol != 0, "task does not have solution");

            let mut task = self.tasks.read(task_id.into());
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.payout_token_erc20.read(),
            };
            let reward_u256: u256 = task.reward;

            let success = token_dispatcher.transfer(task.provider, reward_u256);
            assert(success, 'reward payment failed');

            task.state = TaskState::Closed;
            self.tasks.write(task_id.into(), task);

            self.emit(Event::StatusUpdate(StatusUpdate { id: task_id, status: TaskState::Closed }));
        }
    }

    #[generate_trait]
    impl MarketInternalsImpl of IMarketInternals {
        fn market_fee_percent(ref self: ContractState, market: ContractAddress) -> u8 {
            assert!(market.is_non_zero());
            self.market_distribution_reward_percentage.read()
        }
    }

    #[abi(embed_v0)]
    impl WorkCoreImpl of ICore<ContractState> {
        fn register(ref self: ContractState) {
            self.provider_registrar.write(get_caller_address(), true);
        }

        fn register_task(ref self: ContractState, id: u64, initiator: ContractAddress, provider: ContractAddress, reward: u256, state: TaskState, metadata: felt252, market: ContractAddress) {
            assert!(initiator != provider, "self employment not authorized");
            
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.payout_token_erc20.read(),
            };

            let contract_address = get_contract_address();

            let mut task = Task {
                id,
                initiator,
                provider,
                reward,
                state,
                metadata,
                market
            };

            let success = token_dispatcher
                .transfer_from(task.initiator, contract_address, reward);
            assert!(success, "funding transfer failed");

            let caller = get_caller_address();
            task.initiator = caller;
            task.state = TaskState::Created;
            self.tasks.write(task.id.into(), task.clone());

            if task.provider.is_zero() && provider.is_non_zero() { 
                self.assign_task(task.id, provider); 
            }

            self
                .emit(
                    Event::TaskRegistered(
                        TaskRegistered {
                            id: task.id,
                            initiator: task.initiator,
                            provider: task.provider,
                            amount_funded: task.reward,
                        },
                    ),
                );

            self
            .emit(
                Event::ProviderRegistered(
                    ProviderRegistered { id, address: initiator },
                ),
            );

            let provider_storage_ptr = self.market_registrar.entry(provider);
            let is_registered = provider_storage_ptr.read();

            if !is_registered {
                self.emit(Event::NewProviderRegistarEntry( NewProviderRegistrarEntry { provider: initiator }));
            }
        }

        fn assign_task(
            ref self: ContractState, task_id: u64, provider: ContractAddress,
        ) {
            assert!(!provider.is_zero(), "must assign task to a provider");

            let mut task = self.tasks.read(task_id.into());
            assert!(
                task.state != TaskState::Occupied && task.provider.is_zero(),
                "task previously occupied",
            );

            let non_zero_task_id = task.id.clone();
            task.provider = provider;
            task.state = TaskState::Occupied;
            self.tasks.write(task.id.into(), task);

            let provider_storage_ptr = self.market_registrar.entry(provider);
            let is_registered = provider_storage_ptr.read();

            if !is_registered {
                self
                .emit(
                    Event::ProviderRegistered(
                        ProviderRegistered { id: non_zero_task_id, address: provider },
                    ),
                );
            }
    
        }

        fn get_task(ref self: ContractState, task_id: u64) -> Task {
            self.tasks.read(task_id.into())
        }
    }

    #[abi(embed_v0)]
    impl IExternalEscrowImpl of IExternalEscrow<ContractState> {
        fn reward_addr(self: @ContractState) -> ContractAddress {
            self.payout_token_erc20.read()
        }
    }

    #[abi(embed_v0)]
    impl ICoreMarketImpl of ICoreMarket<ContractState> {
        fn get_ith_market(self: @ContractState, i: u64) -> Option<Market> {
            if let Option::Some(storage_ptr) = self.market_list.get(i) {
                return Option::Some(storage_ptr.read());
            }

            return Option::None;
        }

        fn get_all_markets(self: @ContractState) -> Array<Market> {
            let mut result = ArrayTrait::new();
            let len = self.market_list.len();
            
            let mut i: u64 = 0;
            while i < len {
                if let Option::Some(storage_ptr) = self.market_list.get(i) {
                    let storage_ptr = storage_ptr.read();
                    
                    let market = Market {
                        id: storage_ptr.id,
                    title: storage_ptr.title,
                    metadata: storage_ptr.metadata,
                    metadata_type: storage_ptr.metadata_type,
                    state: storage_ptr.state,
                    m_type: storage_ptr.m_type,
                    addr: storage_ptr.addr
                    };
                    
                    result.append(market);
                }
                i += 1;
            };
            
            result
        }

        fn register_market(
            ref self: ContractState, market: Market 
        ) {
            // Check if the market is already registered and create a storage
            // slot if not.
            let storage_ptr = self.market_registrar.entry(market.addr);
            let is_registered = storage_ptr.read();
        
            if !is_registered {
                storage_ptr.write(true);
                
                let market_list_len = self.market_list.len();
                let market_struct = Market {
                    id: market_list_len,
                    title: market.title,
                    metadata: market.metadata,
                    metadata_type: market.metadata_type,
                    state: market.state,
                    m_type: market.m_type,
                    addr: market.addr
                };
        
                 self.market_list.append().write(market_struct);
            }
        }

        fn finalize_task(
            ref self: ContractState, task_id: u64, verification_hash: NonZero<felt252>,
        ) {
            let mut task = self.tasks.read(task_id.into());

            assert(get_caller_address() == task.provider, 'Unauthorized caller');
            assert(
                (task.state == TaskState::SubmissionDenied
                    || task.state == TaskState::Occupied),
                'Invalid task status',
            );

            let reward = task.reward;
            let market = task.market;
            task.state = TaskState::ApprovalPending;

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
                        StatusUpdate { id: task_id, status: TaskState::ApprovalPending },
                    ),
                );
            
            let market_reward: u256 = reward * self.market_fee_percent(market).into();
            self.distribute_finalization_reward(market, market_reward);
        }
    }

    impl ICoreFeeManagementImpl of ICoreFeeManagement<ContractState> {
        fn set_task_registration_fee_percentage(ref self: ContractState, fee_percentage: u8) {
            self.task_registration_fee_percentage.write(fee_percentage);
        }

        fn get_task_registration_fee_percentage(ref self: ContractState) -> u8 {
            self.task_registration_fee_percentage.read()
        }

        fn distribute_finalization_reward(
            ref self: ContractState, market: ContractAddress, amount: u256,
        ) {
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.payout_token_erc20.read(),
            };

            token_dispatcher.transfer(market, amount);
        }
    }
}
