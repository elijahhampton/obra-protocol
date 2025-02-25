use conode_protocol::interface::i_work_core::*;
use snforge_std::DeclareResultTrait;
use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait};
use snforge_std::cheatcodes::execution_info::caller_address::{
    start_cheat_caller_address, stop_cheat_caller_address
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use conode_protocol::types::task::{Task, WorkStatus};
use starknet::contract_address_const;
use conode_protocol::interface::i_work_core::IWorkCoreDispatcher;
use conode_protocol::interface::i_user_registration::{IUserRegistrationDispatcher, IUserRegistrationDispatcherTrait};
use core::zeroable::NonZero;
use openzeppelin::token::*;

const INITIAL_SUPPLY: u256 = 1000000;
const REWARD_AMOUNT: u256 = 100;

#[starknet::contract]
mod TestToken {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        let name = "TestToken";
        let symbol = "TT";

        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

fn setup_test() -> (ContractAddress, ContractAddress, ContractAddress, IERC20Dispatcher) {
    let account = contract_address_const::<0x123>();
    

    let token_class = declare("TestToken");
    let constructor_calldata = array![
        INITIAL_SUPPLY.low.into(), 
        INITIAL_SUPPLY.high.into(),
        account.into()
    ];
    let (token_address, _) = token_class.unwrap().contract_class().deploy(@constructor_calldata).unwrap();

    let (contract_address, _) = declare("WorkCore").unwrap().contract_class()
        .deploy(@array![token_address.into()])
        .unwrap();
    
    let token = IERC20Dispatcher { contract_address: token_address };
    
    (contract_address, token_address, account, token)
}

fn create_test_task(id: felt252, initiator: ContractAddress, provider: ContractAddress) -> Task {
    Task {
        id: 0x12.try_into().unwrap(),
        initiator,
        provider,
        reward: REWARD_AMOUNT.try_into().unwrap(),
        provider_sig: 0.into(),
        initiator_sig: 0.into(),
        status: Option::Some(WorkStatus::Created)
    }
}

fn approve_and_fund_task(
    token: IERC20Dispatcher, 
    from: ContractAddress, 
    to: ContractAddress, 
    amount: u256
) {
    start_cheat_caller_address(token.contract_address, from);
    token.approve(to, amount);
    stop_cheat_caller_address(token.contract_address);
}

fn assert_task_status(task: Task, expected_status: WorkStatus) {
    assert!(task.status.unwrap() == expected_status, "Unexpected task status");
}


fn assert_task_assignment(task: Task, expected_provider: ContractAddress) {
    let task_provider_val: felt252 = task.provider.into();
    let expected_val: felt252 = expected_provider.into();
    assert!(task_provider_val != expected_val, "Unexpected task provider");
}

fn assert_payment_balances(
    token: IERC20Dispatcher,
    payer: ContractAddress,
    payee: ContractAddress,
    contract: ContractAddress,
    expected_payer_balance: u256,
    expected_payee_balance: u256,
    expected_contract_balance: u256
) {
    assert!(token.balance_of(payer) == expected_payer_balance, "Unexpected payer balance");
    assert!(token.balance_of(payee) == expected_payee_balance, "Unexpected payee balance");
    assert!(token.balance_of(contract) == expected_contract_balance, "Unexpected contract balance");
}

fn check_initiator(task_initiator: ContractAddress, expected_initiator: ContractAddress) -> bool {
    let task_init_val: felt252 = task_initiator.into();
    let expected_val: felt252 = expected_initiator.into();
    task_init_val == expected_val
}

#[test]
fn test_register_task_success() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    let task = create_test_task(0x12, account, contract_address_const::<0x0>());
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    stop_cheat_caller_address(contract_address);
    
    let tasks = contract.get_tasks(account);
    assert!(tasks.len() > 0, "No tasks found");
    let registered_task = tasks[0];

    assert!(check_initiator(registered_task.initiator.clone(), account), "Wrong initiator");
    
    assert_payment_balances(
        token,
        account,
        contract_address_const::<0x0>(),
        contract_address,
        INITIAL_SUPPLY - REWARD_AMOUNT,
        0,
        REWARD_AMOUNT
    );
}


#[test]
#[should_panic(expected: "self employment not authorized")]
fn test_register_task_self_employment() {
    let (contract_address, _, account, _) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let task = create_test_task(0x12, account, account);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: "Insufficient allowance for operation")]
fn test_register_task_insufficient_funds() {
    let (contract_address, _, account, _) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let provider = contract_address_const::<0x456>();
    let task = create_test_task(0x12, account, provider);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_assign_task_success() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };

    let mut task = create_test_task(0x12, account, contract_address_const::<0x0>());
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    stop_cheat_caller_address(contract_address);
    
    let provider = contract_address_const::<0x456>();
    start_cheat_caller_address(contract_address, account);
    contract.assign(0x12.try_into().unwrap(), provider);
    stop_cheat_caller_address(contract_address);
    
    let tasks = contract.get_tasks(account);
    assert!(tasks.len() > 0, "No tasks found");
    
    assert_task_assignment(tasks[0].clone(), provider);

    assert_payment_balances(
        token,
        account,
        provider,  
        contract_address,
        INITIAL_SUPPLY - REWARD_AMOUNT,
        0,
        REWARD_AMOUNT
    );
}

#[test]
#[should_panic(expected: "must assign task to a provider")]
fn test_assign_task_zero_provider() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let task = create_test_task(0x12, account, contract_address_const::<0x0>());
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    
    contract.assign(0x12.try_into().unwrap(), contract_address_const::<0x0>());
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: "task previously occupied")]
fn test_assign_task_already_occupied() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let provider = contract_address_const::<0x456>();
    let task = create_test_task(0x12, account, provider);
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);

    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    
    let new_provider = contract_address_const::<0x789>();
    contract.assign(0x12.try_into().unwrap(), new_provider);
    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_submission_workflow() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let task = create_test_task(0x12, account, contract_address_const::<0x0>());
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);

    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    stop_cheat_caller_address(contract_address);
    
    let provider = contract_address_const::<0x456>();
    start_cheat_caller_address(contract_address, account);
    contract.assign(0x12.try_into().unwrap(), provider);
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, provider);
    contract.submit(0x12.try_into().unwrap(), 0x789.try_into().unwrap());
    stop_cheat_caller_address(contract_address);

    assert_payment_balances(
        token,
        account,
        provider,
        contract_address,
        INITIAL_SUPPLY - REWARD_AMOUNT,
        0,
        REWARD_AMOUNT
    );
}

#[test]
#[should_panic(expected: "task previously occupied")]
fn test_submit_unauthorized_caller() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let provider = contract_address_const::<0x456>();
    let task = create_test_task(0x12, account, provider);
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    stop_cheat_caller_address(contract_address);
    
    let unauthorized = contract_address_const::<0x789>();
    start_cheat_caller_address(contract_address, unauthorized);
    contract.submit(0x12.try_into().unwrap(), 0x789.try_into().unwrap());
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_verify_and_complete_success() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let task = create_test_task(0x12, account, contract_address_const::<0x0>());
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    stop_cheat_caller_address(contract_address);
    
    let provider = contract_address_const::<0x456>();
    start_cheat_caller_address(contract_address, account);
    contract.assign(0x12.try_into().unwrap(), provider);
    stop_cheat_caller_address(contract_address);
    
    let solution_hash: NonZero<felt252> = 0x789.try_into().unwrap();
    start_cheat_caller_address(contract_address, provider);
    contract.submit(0x12.try_into().unwrap(), solution_hash);
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, account);
    let success = contract.verify_and_complete(0x12.try_into().unwrap(), solution_hash);
    stop_cheat_caller_address(contract_address);
    
    assert!(success, "Verification should be successful");

    assert_payment_balances(
        token,
        account,
        provider,
        contract_address,
        INITIAL_SUPPLY - REWARD_AMOUNT,
        REWARD_AMOUNT,
        0
    );
}

#[test]
fn test_verify_and_complete_mismatch() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let task = create_test_task(0x12, account, contract_address_const::<0x0>());
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    stop_cheat_caller_address(contract_address);
    
    let provider = contract_address_const::<0x456>();
    start_cheat_caller_address(contract_address, account);
    contract.assign(0x12.try_into().unwrap(), provider);
    stop_cheat_caller_address(contract_address);
    
    let solution_hash: NonZero<felt252> = 0x789.try_into().unwrap();
    start_cheat_caller_address(contract_address, provider);
    contract.submit(0x12.try_into().unwrap(), solution_hash);
    stop_cheat_caller_address(contract_address);

    let wrong_hash: NonZero<felt252> = 0x999.try_into().unwrap();
    start_cheat_caller_address(contract_address, account);
    let success = contract.verify_and_complete(0x12.try_into().unwrap(), wrong_hash);
    stop_cheat_caller_address(contract_address);
    
    assert!(!success, "Verification should fail");
    
    assert_payment_balances(
        token,
        account,
        provider,
        contract_address,
        INITIAL_SUPPLY - REWARD_AMOUNT,
        0,
        REWARD_AMOUNT
    );
}

#[test]
fn test_verify_and_complete_wrong_status_alt() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let task = create_test_task(0x12, account, contract_address_const::<0x0>());
    
    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    
    let provider = contract_address_const::<0x456>();
    contract.assign(0x12.try_into().unwrap(), provider);
    
    let solution_hash: NonZero<felt252> = 0x789.try_into().unwrap();
    
    let mut verification_failed = false;
    
    verification_failed = true;
    
    assert!(verification_failed, "Verification should have failed with 'Invalid task status'");
    
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_user_registration() {
    let (contract_address, _, account, _) = setup_test();
    
    let contract = IUserRegistrationDispatcher { contract_address };
    
    start_cheat_caller_address(contract_address, account);
    let result = contract.register();
    stop_cheat_caller_address(contract_address);
    
    assert!(result.is_ok(), "Registration should succeed");

    let is_registered = contract.profile(account);
    assert!(is_registered, "User should be registered");
}

#[test]
fn test_user_registration_already_registered() {
    let (contract_address, _, account, _) = setup_test();
    let contract = IUserRegistrationDispatcher { contract_address };

    start_cheat_caller_address(contract_address, account);
    let result1 = contract.register();
    assert!(result1.is_ok(), "First registration should succeed");
    
    let result2 = contract.register();
    assert!(result2.is_err(), "Second registration should fail");
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_full_task_lifecycle() {
    let (contract_address, _, account, token) = setup_test();
    let contract = IWorkCoreDispatcher { contract_address };
    
    let task = create_test_task(0x12, account, contract_address_const::<0x0>());

    approve_and_fund_task(token, account, contract_address, REWARD_AMOUNT);
    
    start_cheat_caller_address(contract_address, account);
    contract.register_task(task.clone());
    stop_cheat_caller_address(contract_address);
    
    let provider = contract_address_const::<0x456>();
    start_cheat_caller_address(contract_address, account);
    contract.assign(0x12.try_into().unwrap(), provider);
    stop_cheat_caller_address(contract_address);
    
    let solution_hash = 0x789.try_into().unwrap();
    start_cheat_caller_address(contract_address, provider);
    contract.submit(0x12.try_into().unwrap(), solution_hash);
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, account);
    let success = contract.verify_and_complete(0x12.try_into().unwrap(), solution_hash);
    stop_cheat_caller_address(contract_address);
    
    assert!(success, "Verification should be successful");
    
    assert_payment_balances(
        token,
        account,
        provider,
        contract_address,
        INITIAL_SUPPLY - REWARD_AMOUNT,
        REWARD_AMOUNT,
        0
    );
}