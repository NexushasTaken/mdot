//! The commands, start to finish. Each returns the process exit code
//! (ADR 0053): 0 success, 1 refused by a rule, 2 error.
//!
//! The order inside `plan`, `apply` and `up` matters:
//!   lock -> read state -> repo check -> load specs -> plan -> (apply)
//! The lock comes before state is read (ADR 0063) and is held until the
//! function returns (the `_lock` value is dropped then).

use crate::apply::{self, Event};
use crate::error::{exit_code, Error};
use crate::facts::Facts;
use crate::host;
use crate::loader::{self, LoadResult, Loaded};
use crate::output::{self, Counts};
use crate::planner::{self, Action, Observed, Step};
use crate::state::{self, State};
use std::collections::HashMap;
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

/// Prints every error and returns their exit code.
fn fail_all(errors: &[Error]) -> u8 {
    for e in errors {
        output::error(&e.message);
    }
    exit_code(errors)
}

fn home_of(facts: &Facts) -> Result<PathBuf, Error> {
    facts
        .dirs
        .iter()
        .find(|(n, _)| *n == "home")
        .and_then(|(_, h)| h.clone())
        .map(PathBuf::from)
        .ok_or_else(|| Error::failed("cannot find the home directory"))
}

/// The real host's name and facts, printing the hostname warning (once per
/// run) and the `hosts/` file warnings (ADR 0070).
fn real_host(repo: &Path) -> Result<Facts, Error> {
    let (name, warning) = host::real_hostname()?;
    if let Some(w) = warning {
        output::warning(&w);
    }
    for w in host::host_file_warnings(repo) {
        output::warning(&w);
    }
    Ok(Facts::of_this_machine(&name))
}

/// A host given on the command line (`preview <host>`: label "host";
/// `specs --host`: label "--host"). No hostname warning (ADR 0071).
fn given_host(repo: &Path, name: &str, label: &str) -> Result<Facts, Error> {
    let (name, warning) = host::given_host_name(name, label)?;
    if let Some(w) = warning {
        output::warning(&w);
    }
    for w in host::host_file_warnings(repo) {
        output::warning(&w);
    }
    Ok(Facts::of_this_machine(&name))
}

/// Everything plan and apply share up to a finished plan.
struct Prepared {
    loaded: Loaded,
    home: PathBuf,
    steps: Vec<Step>,
}

/// Loads the repo and plans it against `state`. Prints errors and returns
/// their exit code on failure.
fn prepare(repo: &Path, state: &State) -> Result<Prepared, u8> {
    let facts = real_host(repo).map_err(fail)?;
    let home = home_of(&facts).map_err(fail)?;
    let result = loader::load(repo, &facts);
    if !result.errors.is_empty() {
        return Err(fail_all(&result.errors));
    }
    let desired: Vec<_> = result.loaded.links().cloned().collect();
    let steps = planner::plan(&desired, state).map_err(fail)?;
    Ok(Prepared { loaded: result.loaded, home, steps })
}

/// ADR 0062, 0073: a different repo than last time asks before going on.
/// Returns false when the user said no.
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
    apply_with(opts, yes, false)
}

/// `mdot up` (ADR 0087): `plan && apply` in one run. One exclusive lock, one
/// plan, printed before the question; the plan that is applied is the one
/// that was shown.
pub fn up(opts: &Options, yes: bool) -> u8 {
    apply_with(opts, yes, true)
}

/// `apply` and `up`. With `show_plan`, the plan is printed first (it also
/// prints `No changes.` and the conflicts), so the refusal line and the
/// second `No changes.` are left out.
fn apply_with(opts: &Options, yes: bool, show_plan: bool) -> u8 {
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

    // apply plans without printing (ADR 0068, 0069); up prints (ADR 0087).
    if show_plan {
        output::print_plan(&p.steps, &p.loaded, &p.home, opts.verbose);
    }
    if p.steps.iter().any(Step::is_conflict) {
        if !show_plan {
            output::conflict("apply refused; run 'mdot plan' to review");
        }
        return 1;
    }
    let has_changes = p.steps.iter().any(|s| s.action != Action::Noop);
    if !has_changes {
        if state.repo.as_deref() != Some(repo.as_path()) {
            // A successful apply stores the repo path (ADR 0062).
            state.repo = Some(repo.clone());
            if let Err(e) = state::save(&dir, &state) {
                return fail(e);
            }
        }
        if !show_plan {
            println!("No changes.");
        }
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

    // Lines are printed in execution order (deletes, then the rest, then
    // creates), one heading each time the spec changes.
    let mut done = Counts::default();
    let mut heading: Option<String> = None;
    let mut report = |event: Event| {
        let step = match &event {
            Event::Warning(w) => return output::warning(w),
            Event::Done(step) if !output::shown(step, opts.verbose) => return,
            Event::Done(step) | Event::Failed(step, _) => *step,
        };
        if heading.as_deref() != Some(step.spec()) {
            println!("{}", step.spec());
            heading = Some(step.spec().to_string());
        }
        let line = output::step_line(step, &p.loaded, &p.home);
        match event {
            Event::Done(_) => {
                println!("{line}");
                if opts.verbose >= 2 {
                    println!("{}", output::explain(step));
                }
                done.add(step.action);
            }
            Event::Failed(_, e) => {
                // The failed step gets `!` in place of its own symbol (ADR 0052).
                println!("  !{}", &line[3..]);
                let dst = output::tilde(step.dst(), &p.home);
                output::error(&format!("{dst}: {}", e.message));
            }
            Event::Warning(_) => unreachable!("handled above"),
        }
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

/// `mdot preview <host>` (ADR 0071): plan's format against an empty machine.
/// Reads only the repo: no live files, no state, no state dir, no lock.
pub fn preview(opts: &Options, host: &str) -> u8 {
    let repo = match loader::find_repo(opts.repo.as_deref()) {
        Ok(r) => r,
        Err(e) => return fail(e),
    };
    let facts = match given_host(&repo, host, "host") {
        Ok(f) => f,
        Err(e) => return fail(e),
    };
    let home = match home_of(&facts) {
        Ok(h) => h,
        Err(e) => return fail(e),
    };
    let result = loader::load(&repo, &facts);
    if !result.errors.is_empty() {
        return fail_all(&result.errors);
    }
    let desired: Vec<_> = result.loaded.links().cloned().collect();
    let empty_machine = |_: &Path| Ok(Observed::Absent);
    let steps = match planner::plan_with(&desired, &State::empty(), empty_machine) {
        Ok(s) => s,
        Err(e) => return fail(e),
    };
    output::print_plan(&steps, &result.loaded, &home, opts.verbose);
    0
}

/// `mdot specs [<name>] [--host <name>]` (ADR 0065). No lock, no state.
pub fn specs(opts: &Options, name: Option<&str>, host: Option<&str>) -> u8 {
    let repo = match loader::find_repo(opts.repo.as_deref()) {
        Ok(r) => r,
        Err(e) => return fail(e),
    };
    let facts = match host {
        Some(h) => given_host(&repo, h, "--host"),
        None => real_host(&repo),
    };
    let facts = match facts {
        Ok(f) => f,
        Err(e) => return fail(e),
    };
    let result = loader::load(&repo, &facts);

    // On a load error: the error first, then whatever did load (ADR 0065).
    let mut code = fail_all(&result.errors);
    if let Some(n) = name {
        if !result.loaded.known.iter().any(|k| k == n) {
            let known = result.loaded.known.join(", ");
            let e = Error::failed(format!("unknown spec \"{n}\"; specs/ has: {known}"));
            code = code.max(fail(e));
            return code;
        }
    }
    print_specs(&result, name);
    code
}

fn print_specs(result: &LoadResult, only: Option<&str>) {
    let loaded = &result.loaded;

    // needed_by[x] = who lists x in depends: specs in dependency order, then
    // the host. A name is listed once per dependent.
    let mut needed_by: HashMap<String, Vec<String>> = HashMap::new();
    let mut add = |dep: &str, who: String| {
        let list = needed_by.entry(dep.to_string()).or_default();
        if !list.contains(&who) {
            list.push(who);
        }
    };
    for spec in &loaded.specs {
        for dep in &spec.depends {
            add(dep, spec.name.clone());
        }
    }
    for dep in &loaded.host_depends {
        add(dep, format!("{} (host)", loaded.host));
    }

    let shown_name = |dep: &String| {
        if loaded.known.contains(dep) { dep.clone() } else { format!("{dep} (missing)") }
    };

    for spec in &loaded.specs {
        if only.is_some_and(|n| n != spec.name) {
            continue;
        }
        println!("{}", spec.name);
        if !spec.depends.is_empty() {
            let deps: Vec<String> = spec.depends.iter().map(shown_name).collect();
            println!("  depends on: {}", deps.join(", "));
        }
        if let Some(who) = needed_by.get(&spec.name) {
            println!("  needed by:  {}", who.join(", "));
        }
    }

    let not_reached: Vec<&String> = loaded
        .not_reached
        .iter()
        .filter(|n| only.is_none_or(|o| o == n.as_str()))
        .collect();
    if !not_reached.is_empty() {
        let names: Vec<&str> = not_reached.iter().map(|s| s.as_str()).collect();
        println!("not reached: {}", names.join(", "));
    }
}
