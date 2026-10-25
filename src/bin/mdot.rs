use clap::{Parser, Subcommand};
use mdot::apply::apply_link;
use mdot::common::{read_file, resolve_path};
use mdot::error::LinkError;
use mdot::link::{plan_link, LinkPlan};
use mdot::spec_lua::parse_spec;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

// Stand-ins for spdlog with the pattern "[%^%=5l%$]: %v": info to stdout,
// errors to stderr (the C++ `errlog` sink).
macro_rules! info {
    ($($arg:tt)*) => { println!("[info ]: {}", format!($($arg)*)) };
}
macro_rules! error {
    ($($arg:tt)*) => { eprintln!("[error]: {}", format!($($arg)*)) };
}

// C++ builds the CLI imperatively with CLI11 (`add_subcommand`, `add_option`).
// clap's derive API describes it as types instead: the enum *is* "exactly one
// subcommand is required", and doc comments become the --help text.
#[derive(Parser)]
#[command(name = "mdot", about = "dotfile manager")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Plan the specified spec
    Plan {
        /// Target of the spec
        spec: PathBuf,
    },
    /// Plan the specified spec
    Apply {
        /// Target of the spec
        spec: PathBuf,
    },
}

struct Core {
    // options
    planning: bool,
}

fn link_plan_describe(core: &Core, plan: &LinkPlan) {
    match plan {
        LinkPlan::Create { src, dst } => {
            if core.planning {
                info!("would linked: {} -> {}", src.display(), dst.display());
            } else {
                info!("linked: {} -> {}", src.display(), dst.display());
            }
        }
        LinkPlan::Noop => info!("already linked"),
        LinkPlan::Conflict { path, message } => error!("{}: {}", path.display(), message),
    }
}

fn process_spec(core: &Core, spec_path: &Path) -> Result<bool, String> {
    let mut success = true;

    if spec_path.is_relative() {
        return Err(format!("{}: must be absolute path", spec_path.display()));
    }

    // C++ `spec_path.filename()` returns an empty path when there's none;
    // Rust returns `Option`, so the "no name" case is explicit.
    let spec_name = spec_path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    let spec_file = spec_path.join("spec.lua");

    {
        let spec_path_st = fs::symlink_metadata(spec_path)
            .map_err(|e| format!("{}: {}", spec_path.display(), e))?;
        if !spec_path_st.is_dir() {
            return Err(format!(
                "{}: is not a valid spec directory",
                spec_file.display()
            ));
        }

        let spec_st = fs::symlink_metadata(&spec_file)
            .map_err(|e| format!("{}: {}", spec_file.display(), e))?;
        if !spec_st.file_type().is_file() {
            return Err(format!("{}: is not a valid spec file", spec_file.display()));
        }
    }

    let previous_path =
        env::current_dir().map_err(|e| format!("{}: {}", spec_path.display(), e))?;
    env::set_current_dir(spec_path).map_err(|e| format!("{}: {}", spec_path.display(), e))?;

    let spec_code =
        read_file(&spec_file).map_err(|e| format!("{}: {}", spec_file.display(), e))?;

    let spec = parse_spec(&spec_name, &spec_code)?;
    if let Ok(cwd) = env::current_dir() {
        info!("{}", cwd.display());
    }

    for clause in &spec.link_clauses {
        let src = resolve_path(Path::new(&clause.src))
            .map_err(|e| format!("{}: {}", clause.src, e))?;
        let dst = resolve_path(Path::new(&clause.dst))
            .map_err(|e| format!("{}: {}", clause.dst, e))?;

        let link_result: Result<LinkPlan, LinkError> = if core.planning {
            plan_link(&src, &dst)
        } else {
            apply_link(&src, &dst)
        };

        let plan = link_result.map_err(|e| e.to_string())?;
        link_plan_describe(core, &plan);

        if plan.is_conflict() {
            success = false;
        }
    }

    env::set_current_dir(&previous_path)
        .map_err(|e| format!("{}: {}", spec_path.display(), e))?;

    Ok(success)
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    let (planning, input_spec_path) = match cli.command {
        Command::Plan { spec } => (true, spec),
        Command::Apply { spec } => (false, spec),
    };
    let core = Core { planning };

    let spec_path = match resolve_path(&input_spec_path) {
        Ok(path) => path,
        Err(e) => {
            error!("{e}");
            return ExitCode::FAILURE;
        }
    };

    match process_spec(&core, &spec_path) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(e) => {
            error!("{e}");
            ExitCode::FAILURE
        }
    }
}
