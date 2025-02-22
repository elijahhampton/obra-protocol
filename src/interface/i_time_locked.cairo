#[starknet::interface]
pub trait ITimeLockedSolutionTrait<TContractState> {
    fn time_deposit_lock(ref self: TContractState, work_id: felt252, deadline: u32);
    fn time_deposit_claim(ref self: TContractState, work_id: felt252);
}