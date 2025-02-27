/// Represents an error or a reason for panicign duration registration
#[derive(Drop, Serde)]
pub enum RegistrationError {
    AlreadyRegistered,
}
