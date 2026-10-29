//! The commands, start to finish. Each returns the process exit code
//! (ADR 0053): 0 success, 1 refused by a rule, 2 error.
//!
//! The order inside `plan` and `apply` matters:
//!   lock -> read state -> repo check -> load specs -> plan -> (apply)
//! The lock comes before state is read (ADR 0063) and is held until the
//! function returns (the `_lock` value is dropped then).

use crate::apply::{self, Event};
use crate::error::{exit_code, Error};
use crate::facts::Facts;
use crate::host;
use crate::loader::{self, Loaded};
use crate::output::{self, Counts};
use crate::planner::{self, Action, Step};
use crate::state::{self, State};
use std::io::{BufRead, IsTerminal, Write};
use std::path::{Path, PathBuf};

pub struct Options {
    pub repo: Option<PathBuf>,
    pub verbose: u8,
}

/// Prints `e` and returns its exit code.
fn fail(e: Error) -> u8 {
    output::error(&e.message);
    e.code as u8
}

/// Everything plan and apply share up to a finished plan.
struct Prepared {
    loaded: Loaded,
    home: PathBuf,
    steps: Vec<Step>,
}

/// Loads the repo and plans it against `state`. Prints load errors and
/// returns their exit code on failure.
fn prepare(repo: &Path, state: &State) -> Result<Prepared, u8> {
    let hostname = host::real_hostname().map_err(fail)?;
    let facts = Facts::of_this_machine(&hostname);
    let home = facts
        .dirs
        .iter()
        .find(|(n, _)| *n == "home")
        .and_then(|(_, h)| h.clone())
        .map(PathBuf::from)
        .ok_or_else(|| fail(Error::failed("cannot find the home directory")))?;

    let result = loader::load(repo, &facts);
    if !result.errors.is_empty() {
        for e in &result.errors {
            output::error(&e.message);
        }
        return Err(exit_code(&result.errors));
    }
    let desired: Vec<_> = result.loaded.links().cloned().collect();
    let steps = planner::plan(&desired, state).map_err(fail)?;
    Ok(Prepared { loaded: result.loaded, home, steps })
}

/// ADR 0062, 0073: a different repo than last time asks before going on.
/// Returns false when the user said no or cannot be asked.
fn repo_check(state: &State, repo: &Path) -> Result<bool, u8> {
    match &state.repo {
        Some(old) if old != repo => {
            output::warning(&format!(
                "state is from repo {}, this is {}",
                old.display(),
                repo.display()
            ));
            if !std::io::stdin().is_terminal() {
                return Err(fail(Error::refused(
                    "cannot ask to continue: stdin is not a terminal",
                )));
            }
            ask("continue anyway? [y/N] ").map_err(fail)
        }
        _ => Ok(true),
    }
}

/// One prompt (ADR 0072): one line, trimmed, `y`/`yes` in any case is yes,
/// anything else is no. EOF prints a newline and is no.
fn ask(question: &str) -> Result<bool, Error> {
    let mut err = std::io::stderr();
    let _ = write!(err, "{question}");
    let _ = err.flush();
    let mut line = String::new();
    let n = std::io::stdin()
        .lock()
        .read_line(&mut line)
        .map_err(|e| Error::failed(format!("cannot read the answer: {e}")))?;
    if n == 0 {
        let _ = writeln!(err);
        return Ok(false);
    }
    let answer = line.trim().to_ascii_lowercase();
    Ok(answer == "y" || answer == "yes")
}

pub fn plan(opts: &Options) -> u8 {
    let repo = match loader::find_repo(opts.repo.as_deref()) {
        Ok(r) => r,
        Err(e) => return fail(e),
    };
    let dir = match state::state_dir() {
        Ok(d) => d,
        Err(e) => return fail(e),
    };
    let _lock = match state::lock_shared(&dir) {
        Ok(l) => l,
        Err(e) => return fail(e),
    };
    // plan reads state but never writes it, not even a migration (ADR 0075).
    let state = match state::load(&dir) {
        Ok(s) => s,
        Err(e) => return fail(e),
    };
    match repo_check(&state, &repo) {
        Ok(true) => {}
        Ok(false) => return 1,
        Err(code) => return code,
    }
    let p = match prepare(&repo, &state) {
        Ok(p) => p,
        Err(code) => return code,
    };

    output::print_plan(&p.steps, &p.loaded, &p.home, opts.verbose);
    if p.steps.iter().any(Step::is_conflict) { 1 } else { 0 }
}

pub fn apply(opts: &Options, yes: bool) -> u8 {
    let repo = match loader::find_repo(opts.repo.as_deref()) {
        Ok(r) => r,
        Err(e) => return fail(e),
    };
    let dir = match state::state_dir() {
        Ok(d) => d,
        Err(e) => return fail(e),
    };
    let _lock = match state::lock_exclusive(&dir) {
        Ok(l) => l,
        Err(e) => return fail(e),
    };
    let mut state = match state::load(&dir) {
        Ok(s) => s,
        Err(e) => return fail(e),
    };
    // --yes does not answer this question (ADR 0062).
    match repo_check(&state, &repo) {
        Ok(true) => {}
        Ok(false) => return 1,
        Err(code) => return code,
    }
    let p = match prepare(&repo, &state) {
        Ok(p) => p,
        Err(code) => return code,
    };

    // Plan first, without printing (ADR 0068, 0069).
    if p.steps.iter().any(Step::is_conflict) {
        output::conflict("apply refused; run 'mdot plan' to review");
        return 1;
    }
    let has_changes = p.steps.iter().any(|s| s.action != Action::Noop);
    let repo_changed = state.repo.as_deref() != Some(repo.as_path());
    if !has_changes {
        if repo_changed {
            // A successful apply stores the repo path (ADR 0062).
            state.repo = Some(repo.clone());
            if let Err(e) = state::save(&dir, &state) {
                return fail(e);
            }
        }
        println!("No changes.");
        return 0;
    }

    if !yes {
        if !std::io::stdin().is_terminal() {
            return fail(Error::refused(
                "cannot ask for confirmation: stdin is not a terminal; use --yes",
            ));
        }
        match ask("apply? [y/N] ") {
            Ok(true) => {}
            Ok(false) => return 0,
            Err(e) => return fail(e),
        }
    }

    // TODO(design): apply prints in execution order (deletes, then the rest,
    // then creates), which can differ from plan's spec order (ADR 0051/0052).
    let mut done = Counts::default();
    let mut heading: Option<String> = None;
    let mut report = |event: Event| match event {
        Event::Done(step) | Event::Failed(step, _) if heading.as_deref() != Some(step.spec()) => {
            println!("{}", step.spec());
            heading = Some(step.spec().to_string());
            print_event(event, &p, &mut done);
        }
        other => print_event(other, &p, &mut done),
    };
    let result = apply::apply(&p.steps, &mut state, &dir, &mut report);

    if result.is_ok() {
        state.repo = Some(repo.clone());
        if let Err(e) = state::save(&dir, &state) {
            return fail(e);
        }
    }
    println!();
    println!("{}", output::apply_summary(done));
    if result.is_ok() { 0 } else { 2 }
}

fn print_event(event: Event, p: &Prepared, done: &mut Counts) {
    match event {
        Event::Done(step) => {
            println!("{}", output::step_line(step, &p.loaded, &p.home));
            done.add(step.action);
        }
        Event::Failed(step, e) => {
            let line = output::step_line(step, &p.loaded, &p.home);
            // The failed step gets `!` in place of its own symbol (ADR 0052).
            println!("  !{}", &line[3..]);
            let dst = output::tilde(step.dst(), &p.home);
            output::error(&format!("{dst}: {}", e.message));
        }
        Event::Warning(w) => output::warning(&w),
    }
}

/// `mdot preview <host>` (ADR 0071).
pub fn preview(_opts: &Options, host: &str) -> u8 {
    if let Err(e) = host::given_host_name(host) {
        return fail(e);
    }
    // TODO(build): load with Facts::of_this_machine(host), plan against
    // State::empty() without observing live (every resource is new), print.
    // No state dir, no lock, no live files.
    todo!("build: mdot preview (ADR 0071)")
}

/// `mdot specs [<name>] [--host <name>]` (ADR 0065).
pub fn specs(_opts: &Options, _name: Option<&str>, _host: Option<&str>) -> u8 {
    // TODO(build): load (no lock), then print each reached spec with
    // `depends on:` / `needed by:` and the `not reached:` line. Loaded has
    // specs (dependency order), each spec's depends, host_depends, not_reached.
    todo!("build: mdot specs (ADR 0065)")
}
