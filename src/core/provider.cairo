/// A profile agnostic to a TaskProvider or ServiceProvider that tracks 
/// work history and related attributes.
#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Profile {}

pub trait TProfile {
    fn new() -> Profile;
}

impl ProfileImpl of TProfile {
    fn new() -> Profile {
        let profile = Profile {};
        profile
    }
}
