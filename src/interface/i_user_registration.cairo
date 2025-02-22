#[starknet::interface]
#[derive(Serde)]
pub trait IUserRegistration<TContractState> {
    fn register(ref self: TContractState) -> bool;
}
