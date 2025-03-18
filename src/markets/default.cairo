/// A default market contract showing an example implementnation of a market without support for
/// disputes, reputation management and workflow hooks.
///
/// @dev Do not use this contract in production.
/// @note This contract serves as a demonstration of a market for MVP purposes and will continue to
/// develop.
#[starknet::contract]
pub mod DefaultMarket {
    use super::super::super::interface::i_core::IExternalEscrowDispatcherTrait;
    use crate::interface::i_market::{IMarket, MarketType};
    use starknet::{get_caller_address, get_contract_address, ContractAddress};
    use core::zeroable::NonZero;
    use starknet::storage::Map;
    use crate::interface::i_core::{
        ICoreMarketDispatcher, ICoreMarketDispatcherTrait, IExternalEscrowDispatcher,
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    pub struct Storage {
        core: ContractAddress,
        market_type: MarketType,
        solution_registry: Map<felt252, felt252>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, core: ContractAddress, market_type: MarketType) {
        self.core.write(core);
        self.market_type.write(market_type);
    }

    #[abi(embed_v0)]
    impl IMarketImpl of IMarket<ContractState> {
        fn submit_completion(
            ref self: ContractState, task_id: u64, verification_hash: NonZero<felt252>,
        ) {
            let verification_hash_raw = verification_hash.into();
            let stored_solution = self.solution_registry.read(task_id.into());
            if verification_hash_raw == stored_solution {
                panic!("cannot submit the same verification hash twice consecutively");
            }

            self.solution_registry.write(task_id.into(), verification_hash_raw);

            let core_dispatcher = ICoreMarketDispatcher { contract_address: self.core.read() };

            // Mandatory call to core contract to properly finalize the task in the global
            // registry
            core_dispatcher.finalize_task(task_id, verification_hash);
        }

        fn market_type(ref self: ContractState) -> MarketType {
            MarketType::Basic
        }

        fn pay_fee(ref self: ContractState, task_id: felt252, amount: u256) {
            let core_addr = self.core.read();
            let caller = get_caller_address();
            assert!(caller == core_addr, "only core should pay fees");

            let escrow_dispatcher = IExternalEscrowDispatcher {
                contract_address: self.core.read(),
            };
            let erc20_dispatcher = IERC20Dispatcher {
                contract_address: escrow_dispatcher.reward_addr(),
            };

            let this_address = get_contract_address();

            erc20_dispatcher.transfer_from(core_addr, this_address, amount);
        }

        fn pre_task_creation(
            self: @ContractState, task_id: felt252, description: felt252, reward: felt252,
        ) -> felt252 {
            1
        }

        fn post_task_creation(
            ref self: ContractState, task_id: felt252,
        ) { // Unimplemented: Contract does not support hooks
        }

        fn pre_task_assignment(
            self: @ContractState, task_id: felt252, provider: felt252,
        ) -> felt252 {
            1
        }

        fn post_task_assignment(ref self: ContractState, task_id: felt252, provider: felt252) {}

        fn supports_disputes(self: @ContractState) -> u8 {
            0
        }

        fn supports_hooks(self: @ContractState) -> u8 {
            0
        }

        fn initiate_dispute(
            ref self: ContractState, task_id: felt252, reason: felt252,
        ) { // Unimplemented: Contract does not support disputes 
        }

        fn supports_reputation_management(self: @ContractState) -> u8 {
            0
        }

        fn resolve_dispute(
            ref self: ContractState, task_id: felt252, approve: felt252,
        ) { // Unimplemented: Contract does not support disputes
        }
    }
}
