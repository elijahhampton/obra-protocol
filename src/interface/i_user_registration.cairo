use starknet::ContractAddress;
use super::super::core::error::RegistrationError;

#[starknet::interface]
#[derive(Serde)]
pub trait IUserRegistration<TContractState> {
    fn register(ref self: TContractState) -> Result<(), RegistrationError>;
    fn profile(ref self: TContractState, address: ContractAddress) -> bool;
}
