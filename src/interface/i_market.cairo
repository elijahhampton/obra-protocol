use core::zeroable::NonZero;

#[starknet::interface]
pub trait IMarket<TContractState> {
    fn submit_completion(task_id: NonZero<felt252>, verification_hash: NonZero<felt252>);
    fn pay_fee(task_id: u256);
}