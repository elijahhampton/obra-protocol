use starknet::ContractAddress;

// --- WorkCore Payments ---
#[event]
#[derive(Drop, starknet::Event)]
pub enum PaymentEvent {
   PaymentCreated: PaymentCreated,
   PaymentDistributed: PaymentDistributed,
   PaymentLocked: PaymentLocked,
   PaymentReleased: PaymentReleased
}

#[derive(Drop, starknet::Event)]
struct PaymentCreated {
   payment_id: u256,
   amount: u256,
   market_id: felt252
}

#[derive(Drop, starknet::Event)]
struct PaymentDistributed {
   payment_id: u256,
   recipient: ContractAddress,
   amount: u256
}

#[derive(Drop, starknet::Event)]
struct PaymentLocked {
   payment_id: u256,
   dispute_id: u256
}

#[derive(Drop, starknet::Event)]
struct PaymentReleased {
   payment_id: u256,
   dispute_id: Option<u256>
}
