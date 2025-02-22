use starknet::ContractAddress;

#[starknet::interface]
pub trait IUserSummaryTrait<TContractState> {
    fn task_list(ref self: TContractState, address: ContractAddress);
    fn create_summary(ref self: TContractState);
}
