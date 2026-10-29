//! Running a clean plan (design.typ "Apply", ADR 0029, 0033, 0060).
//!
//! The rule that keeps a crash safe: *disk first, then state*. Each step
//! changes the disk, then saves state once. State can lag the disk (the next
//! plan adopts or forgets the difference) but never leads it.

use crate::common::create_symlink;
use crate::error::Error;
use crate::planner::{Action, Step};
use crate::state::{self, LinkRecord, Record, State};
use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

/// What happened, reported as it happens so output can print each line right
/// after its step (ADR 0052).
pub enum Event<'a> {
    Done(&'a Step),
    Failed(&'a Step, Error),
    Warning(String),
}

/// Runs `steps` (already in apply order) and saves state after each one. The
/// caller has checked there are no conflicts. Stops at the first failure and
/// returns its error.
///
/// `report` is a closure the caller passes in: `&mut dyn FnMut(Event)` means
/// "any function or closure taking an Event, which may change what it
/// captured" (like a C callback plus its `void *user` pointer, in one value).
pub fn apply(
    steps: &[Step],
    state: &mut State,
    state_dir: &Path,
    report: &mut dyn FnMut(Event),
) -> Result<(), Error> {
    for step in steps {
        if step.is_conflict() {
            // Never reached: the caller refuses a plan with conflicts.
            unreachable!("apply called with a conflict: {}", step.id);
        }
        if step.action == Action::Noop {
            // Nothing to do; reported so `-v` can show its `=` line.
            report(Event::Done(step));
            continue;
        }
        match run_step(step, state, state_dir, report) {
            Ok(()) => report(Event::Done(step)),
            Err(e) => {
                report(Event::Failed(step, e.clone()));
                return Err(e);
            }
        }
    }
    Ok(())
}

fn run_step(
    step: &Step,
    state: &mut State,
    dir: &Path,
    report: &mut dyn FnMut(Event),
) -> Result<(), Error> {
    let dst = step.dst().to_path_buf();
    match step.action {
        Action::Create | Action::Recreate => {
            make_parents(&dst, state, dir)?;
            let d = step.desired.as_ref().expect("create has a desired side");
            create_symlink(&d.src, &dst)
                .map_err(|e| Error::failed(format!("could not create link: {e}")))?;
            state.put(record_of(step));
        }
        Action::Adopt => state.put(record_of(step)),
        Action::Update => {
            // `dst` is missing between these two calls (design.typ "Apply").
            remove_link(&dst).map_err(|e| Error::failed(format!("could not remove old link: {e}")))?;
            let d = step.desired.as_ref().expect("update has a desired side");
            create_symlink(&d.src, &dst)
                .map_err(|e| Error::failed(format!("could not create link: {e}")))?;
            state.put(record_of(step));
        }
        Action::Delete => {
            remove_link(&dst).map_err(|e| Error::failed(format!("could not remove link: {e}")))?;
            prune_dirs(state, &step.id, report);
            state.remove(&step.id);
        }
        Action::Forget => {
            prune_dirs(state, &step.id, report);
            state.remove(&step.id);
        }
        Action::Noop | Action::Conflict | Action::ConflictDrift => {}
    }
    state::save(dir, state)
}

/// The record a create/update/adopt leaves behind: the desired side.
fn record_of(step: &Step) -> Record {
    let d = step.desired.as_ref().expect("step has a desired side");
    Record::Link(LinkRecord { spec: d.spec.clone(), src: d.src.clone(), dst: d.dst.clone() })
}

/// Creates the missing parents of `dst`, top down, recording each one in
/// `created_dirs` right after it is made (ADR 0060). Directories that already
/// existed are never recorded.
fn make_parents(dst: &Path, state: &mut State, dir: &Path) -> Result<(), Error> {
    let mut missing: Vec<PathBuf> = Vec::new();
    let mut cur = dst.parent();
    while let Some(p) = cur {
        match fs::symlink_metadata(p) {
            Ok(_) => break,
            Err(e) if e.kind() == ErrorKind::NotFound => missing.push(p.to_path_buf()),
            Err(e) => return Err(Error::failed(format!("{}: {e}", p.display()))),
        }
        cur = p.parent();
    }
    // `missing` is bottom up; create top down.
    for p in missing.into_iter().rev() {
        fs::create_dir(&p)
            .map_err(|e| Error::failed(format!("could not create directory {}: {e}", p.display())))?;
        state.created_dirs.push(p);
        state::save(dir, state)?;
    }
    Ok(())
}

/// After `removing` goes away: rmdir every recorded directory that no other
/// record's `dst` is under, deepest first. Usage is derived from the records,
/// never counted. A directory that is not empty (or fails for any other
/// reason) is left alone, warned about and dropped from state.
fn prune_dirs(state: &mut State, removing: &str, report: &mut dyn FnMut(Event)) {
    let mut dirs = state.created_dirs.clone();
    // Deepest first: more components = deeper.
    dirs.sort_by_key(|d| std::cmp::Reverse(d.components().count()));

    for d in dirs {
        let in_use = state
            .links()
            .any(|r| state::link_id(&r.dst) != removing && r.dst.starts_with(&d));
        if in_use {
            continue;
        }
        match fs::remove_dir(&d) {
            Ok(()) => {}
            Err(e) if e.kind() == ErrorKind::NotFound => {}
            Err(e) if e.kind() == ErrorKind::DirectoryNotEmpty => {
                report(Event::Warning(format!("{}: not removed, it is not empty", d.display())))
            }
            Err(e) => report(Event::Warning(format!("{}: not removed: {e}", d.display()))),
        }
        state.created_dirs.retain(|x| x != &d);
    }
}

/// Removes the symlink at `dst` itself, never what it points to.
fn remove_link(dst: &Path) -> std::io::Result<()> {
    match fs::remove_file(dst) {
        // Windows: a directory symlink is removed with remove_dir.
        #[cfg(windows)]
        Err(_) => fs::remove_dir(dst),
        other => other,
    }
}
