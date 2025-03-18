#[starknet::interface]
pub trait ITaskProvider<TContractState> {
    fn task_created(ref self: TContractState);
    fn task_resolved(ref self: TContractState);
}

#[starknet::interface]
pub trait IServiceProvider<TContractState> {
    fn task_completed(ref self: TContractState);
    fn task_accepted(ref self: TContractState);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (account/account.cairo)

/// # Provider Account
///
/// The Provider account contract represents an account as a smart contract for Task Providers
/// and Service Providers.
#[starknet::contract(account)]
pub mod ProviderAccount {
    use ProviderAccountComponent::InternalTrait;
    use conode_protocol::components::provider_account_component::ProviderAccountComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use super::ITaskProvider;
    use super:: IServiceProvider;

    component!(path: ProviderAccountComponent, storage: provider, event: ProviderEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccountMixinImpl =
        ProviderAccountComponent::AccountMixinImpl<ContractState>;
    impl AccountInternalImpl = ProviderAccountComponent::InternalImpl<ContractState>;

    #[derive(Drop, Serde)]
    struct TaskProviderProfile {
        task_created: u64
    }

    #[derive(Drop, Serde)]
    struct ServiceProviderProfile {
        task_completed: u64
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        provider: ProviderAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        task_provider: TaskProviderProfile,
        service_provider: ServiceProviderProfile
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ProviderEvent: ProviderAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.provider.initializer(public_key);
    }

    #[abi(embed_v0)]
    impl TaskProviderImpl of ITaskProvider<ContractState> {
        fn task_created(ref self: ContractState) {

        }

        fn task_resolved(ref self: ContractState) {}    
    }

    #[abi(embed_v0)]
    impl ServiceProviderImpl of IServiceProvider<ContractState> {
        fn task_completed(ref self: ContractState) {} 

        fn task_accepted(ref self: ContractState) {}
    }
}
