use core::array::ArrayTrait;
use core::traits::Into;
use core::option::OptionTrait;
use core::result::ResultTrait;
use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use conode_protocol::interface::i_user_registration::IUserRegistrationDispatcher;
use conode_protocol::interface::i_user_registration::IUserRegistrationDispatcherTrait;

use snforge_std::cheatcodes::execution_info::caller_address::{
    start_cheat_caller_address, stop_cheat_caller_address,
};

#[test]
fn test_user_registration() {
    let contract = declare("WorkCore").unwrap().contract_class();
    let mut calldata: Array<felt252> = ArrayTrait::new();
    let erc20_addr: ContractAddress = 123.try_into().unwrap();
    calldata.append(erc20_addr.into());
    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let dispatcher = IUserRegistrationDispatcher { contract_address };
    let caller_addr: ContractAddress = 456.try_into().unwrap();

    start_cheat_caller_address(contract_address, caller_addr);
    dispatcher.register().unwrap();
    stop_cheat_caller_address(contract_address);

    let profile = dispatcher.profile(caller_addr);
    assert(profile, 'Profile should exist');
}
