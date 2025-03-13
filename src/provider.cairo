// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (account/account.cairo)

/// # Provider Account
///
/// The Provider account contract represents an account as a smart contract for Task Providers
/// and Service Providers.
#[starknet::contract(account)]
pub mod ProviderAccount {
    use ProviderAccountComponent::InternalTrait;
    use openzeppelin::account::interface::AccountABI;
    use conode_protocol::components::provider_account_component::ProviderAccountComponent;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: ProviderAccountComponent, storage: provider, event: ProviderEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccountMixinImpl =
        ProviderAccountComponent::AccountMixinImpl<ContractState>;
    impl AccountInternalImpl = ProviderAccountComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        provider: ProviderAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
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
}
