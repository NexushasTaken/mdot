//! Rust port of the C++ mdot prototype. One module per C++ translation unit:
//!
//! | C++                     | Rust               |
//! |-------------------------|--------------------|
//! | error.hpp / error.cpp   | `error`            |
//! | common.hpp / common.cpp | `common`           |
//! | link.hpp / link.cpp     | `link`             |
//! | apply.hpp / apply.cpp   | `apply`            |
//! | spec.hpp                | `spec`             |
//! | spec_lua.hpp / .cpp     | `spec_lua`         |
//! | planner.hpp / .cpp      | `planner`          |
//! | main.cpp                | `src/bin/mdot.rs`  |

pub mod apply;
pub mod common;
pub mod error;
pub mod link;
pub mod planner;
pub mod spec;
pub mod spec_lua;
