//! What the user sees (design.typ "Output", ADR 0050, 0051, 0052).
//!
//! Plan and `mdot.print` go to stdout; `error:`, `conflict:` and `warning:`
//! lines go to stderr.
//!
//! TODO(build): `--color` (ADR 0086), `-v=2` (desired/recorded/live per
//! resource), padding when a second kind exists. Everything else in this file
//! follows the spec; change it freely, nothing else depends on the format.

use crate::loader::Loaded;
use crate::planner::{Action, Step};
use std::path::Path;

pub fn error(message: &str) {
    eprintln!("error: {message}");
}

pub fn conflict(message: &str) {
    eprintln!("conflict: {message}");
}

pub fn warning(message: &str) {
    eprintln!("warning: {message}");
}

/// `~/x` for a path under home, else the path as is. Used where only the
/// absolute path is known (a record whose spec is gone).
pub fn tilde(path: &Path, home: &Path) -> String {
    match path.strip_prefix(home) {
        Ok(rest) if rest.as_os_str().is_empty() => "~".to_string(),
        Ok(rest) => format!("~/{}", rest.display()),
        Err(_) => path.display().to_string(),
    }
}

fn symbol(action: Action) -> char {
    match action {
        Action::Create | Action::Recreate => '+',
        Action::Update | Action::Adopt => '~',
        Action::Delete | Action::Forget => '-',
        Action::Noop => '=',
        Action::Conflict | Action::ConflictDrift => '!',
    }
}

/// The optional `(detail)` after a line.
/// TODO(design): the wording for adopt, re-create and forget is not in
/// design.typ; these are placeholders.
fn detail(step: &Step, loaded: &Loaded) -> Option<&'static str> {
    match step.action {
        Action::Recreate => Some("removed by hand"),
        Action::Adopt => Some("already linked; record only"),
        Action::Forget => Some("already gone"),
        Action::Delete if loaded.spec(step.spec()).is_none() => Some("spec removed"),
        Action::Delete => Some("clause removed"),
        _ => None,
    }
}

/// `  + link  ~/.config/waybar -> config  (detail)`
pub fn step_line(step: &Step, loaded: &Loaded, home: &Path) -> String {
    let mut line = match &step.desired {
        Some(d) => format!("  {} link  {} -> {}", symbol(step.action), d.dst_shown, d.src_shown),
        None => format!("  {} link  {}", symbol(step.action), tilde(step.dst(), home)),
    };
    if let Some(d) = detail(step, loaded) {
        line.push_str(&format!("  ({d})"));
    }
    line
}

fn shown_dst(step: &Step, home: &Path) -> String {
    match &step.desired {
        Some(d) => d.dst_shown.clone(),
        None => tilde(step.dst(), home),
    }
}

pub fn conflict_line(step: &Step, home: &Path) {
    conflict(&format!("{}: {}", shown_dst(step, home), step.conflict_reason()));
}

/// Steps in display order (ADR 0051): specs in dependency order, each spec's
/// resources in declaration order. Records of specs that are no longer
/// reached come last, by spec name, then by ID.
pub fn display_order<'a>(steps: &'a [Step], loaded: &Loaded) -> Vec<&'a Step> {
    let unreached_base = loaded.specs.len();
    let key = |s: &Step| -> (usize, String, usize, String) {
        let spec_index = loaded.specs.iter().position(|l| l.name == s.spec());
        let link_index = spec_index
            .and_then(|i| loaded.specs[i].links.iter().position(|l| l.dst == s.dst()))
            .unwrap_or(usize::MAX);
        match spec_index {
            Some(i) => (i, String::new(), link_index, s.id.clone()),
            None => (unreached_base, s.spec().to_string(), link_index, s.id.clone()),
        }
    };
    let mut ordered: Vec<&Step> = steps.iter().collect();
    ordered.sort_by_key(|s| key(s));
    ordered
}

fn shown(step: &Step, verbose: u8) -> bool {
    step.action != Action::Noop || verbose >= 1
}

/// Prints the plan. Headings appear only above a line that is shown.
pub fn print_plan(steps: &[Step], loaded: &Loaded, home: &Path, verbose: u8) {
    let mut heading: Option<&str> = None;
    for step in display_order(steps, loaded) {
        if !shown(step, verbose) {
            continue;
        }
        if heading != Some(step.spec()) {
            println!("{}", step.spec());
            heading = Some(step.spec());
        }
        println!("{}", step_line(step, loaded, home));
        if step.is_conflict() {
            conflict_line(step, home);
        }
    }
    let summary = plan_summary(steps);
    if heading.is_some() && summary != "No changes." {
        println!();
    }
    println!("{summary}");
}

/// Counts for the summary line.
/// TODO(design): design.typ only names create/delete/conflict; adopt is
/// counted as an update and forget as a delete here.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct Counts {
    pub create: usize,
    pub update: usize,
    pub delete: usize,
    pub conflict: usize,
}

impl Counts {
    pub fn add(&mut self, action: Action) {
        match action {
            Action::Create | Action::Recreate => self.create += 1,
            Action::Update | Action::Adopt => self.update += 1,
            Action::Delete | Action::Forget => self.delete += 1,
            Action::Conflict | Action::ConflictDrift => self.conflict += 1,
            Action::Noop => {}
        }
    }
    pub fn of(steps: &[Step]) -> Counts {
        let mut c = Counts::default();
        for s in steps {
            c.add(s.action);
        }
        c
    }
}

/// `Plan: 2 to create, 1 to delete, 1 conflict.` or `No changes.`
pub fn plan_summary(steps: &[Step]) -> String {
    let c = Counts::of(steps);
    let mut parts = Vec::new();
    if c.create > 0 { parts.push(format!("{} to create", c.create)); }
    if c.update > 0 { parts.push(format!("{} to update", c.update)); }
    if c.delete > 0 { parts.push(format!("{} to delete", c.delete)); }
    if c.conflict > 0 {
        parts.push(format!("{} conflict{}", c.conflict, if c.conflict == 1 { "" } else { "s" }));
    }
    if parts.is_empty() { "No changes.".to_string() } else { format!("Plan: {}.", parts.join(", ")) }
}

/// `Applied: 2 created, 1 updated, 1 deleted.` or `Applied: nothing.`
pub fn apply_summary(done: Counts) -> String {
    let mut parts = Vec::new();
    if done.create > 0 { parts.push(format!("{} created", done.create)); }
    if done.update > 0 { parts.push(format!("{} updated", done.update)); }
    if done.delete > 0 { parts.push(format!("{} deleted", done.delete)); }
    if parts.is_empty() { "Applied: nothing.".to_string() } else { format!("Applied: {}.", parts.join(", ")) }
}
