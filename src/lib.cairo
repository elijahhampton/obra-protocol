//! Conode Protocol Library
//! Main library file for the Conode Protocol

// Interface modules
pub mod interface {
    pub mod i_work_core;
    pub mod i_user_registration;
    pub mod i_work_summary;
    pub mod i_market_core;
    pub mod i_market_payment;
    pub mod i_time_locked;
}

// Core implementation modules
pub mod core {
    pub mod work_core;
}

// External interfaces and implementations
pub mod external {
    pub mod interface {
        pub mod i_market;
    }
}

// Event definitions
pub mod events {
    pub mod dispute;
    pub mod payment;
}

// Common types and structures
pub mod types {
    pub mod dispute;
    pub mod solution;
    pub mod task;
}
