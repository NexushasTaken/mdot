//! mdot's library. The binary (`src/bin/mdot.rs`) only parses arguments and
//! calls `run`. One run, top to bottom:
//!
//! | Step                                   | Module    |
//! |----------------------------------------|-----------|
//! | parse the command line                 | bin/mdot  |
//! | lock, read state, check the repo path  | `state`   |
//! | hostname and machine facts             | `host`, `facts` |
//! | run config.lua, host file, specs       | `loader` (uses `sandbox`) |
//! | 3-way diff into steps                  | `planner` |
//! | print the plan                         | `output`  |
//! | run the steps, save state after each   | `apply`   |
//!
//! `run` ties them together, one function per command.

pub mod apply;
pub mod common;
pub mod error;
pub mod facts;
pub mod host;
pub mod loader;
pub mod output;
pub mod planner;
pub mod run;
pub mod sandbox;
pub mod state;
pub mod vars;
