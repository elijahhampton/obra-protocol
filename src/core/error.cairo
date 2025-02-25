#[derive(Drop, Serde)]
pub enum RegistrationError {
    AlreadyRegistered,
}
