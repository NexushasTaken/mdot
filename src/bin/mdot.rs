//! The command line (design.typ "CLI"). Only parsing lives here; the commands
//! are in `mdot::run`.

use clap::{Parser, Subcommand, ValueEnum};
use mdot::output::ColorWhen;
use mdot::run::{self, Options};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser)]
#[command(name = "mdot", version, about = "Declarative dotfile manager")]
struct Cli {
    /// The repo root (default: the current directory, if it has specs/)
    #[arg(long, global = true, value_name = "DIR")]
    repo: Option<PathBuf>,

    /// Verbosity: -v is 1, -v=2 shows more. A level is attached with `=`.
    #[arg(
        short,
        long,
        global = true,
        num_args = 0..=1,
        require_equals = true,
        default_missing_value = "1",
        value_name = "LEVEL"
    )]
    verbose: Option<u8>,

    /// When to color errors, conflicts and warnings (ADR 0086)
    #[arg(long, global = true, value_enum, default_value_t = Color::Auto, value_name = "WHEN")]
    color: Color,

    #[command(subcommand)]
    command: Command,
}

#[derive(Clone, Copy, ValueEnum)]
enum Color {
    Auto,
    Always,
    Never,
}

#[derive(Subcommand)]
enum Command {
    /// Show what apply would do
    Plan,
    /// Execute the plan
    Apply {
        /// Do not ask for confirmation
        #[arg(long)]
        yes: bool,
    },
    /// Show what hosts/<host>.lua would get on an empty machine
    Preview { host: String },
    /// Show each spec's dependencies and what needs it
    Specs {
        name: Option<String>,
        #[arg(long)]
        host: Option<String>,
    },
}

/// Rust ignores SIGPIPE, so `mdot plan | head` would panic on the first
/// write after `head` exits. A CLI should just die quietly, like C programs.
#[cfg(unix)]
fn restore_sigpipe() {
    // SAFETY: called first thing in main, before any other thread exists.
    unsafe {
        libc::signal(libc::SIGPIPE, libc::SIG_DFL);
    }
}

#[cfg(not(unix))]
fn restore_sigpipe() {}

fn main() -> ExitCode {
    restore_sigpipe();
    let cli = Cli::parse();
    mdot::output::set_color(match cli.color {
        Color::Auto => ColorWhen::Auto,
        Color::Always => ColorWhen::Always,
        Color::Never => ColorWhen::Never,
    });
    let opts = Options { repo: cli.repo, verbose: cli.verbose.unwrap_or(0) };

    let code = match cli.command {
        Command::Plan => run::plan(&opts),
        Command::Apply { yes } => run::apply(&opts, yes),
        Command::Preview { host } => run::preview(&opts, &host),
        Command::Specs { name, host } => run::specs(&opts, name.as_deref(), host.as_deref()),
    };
    ExitCode::from(code)
}
