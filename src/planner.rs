use crate::error::Error;
use crate::loader::DesiredLink;
use crate::state::{self, State};
use std::collections::BTreeMap;
use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

// `Copy` lets these enums be passed by value like a C enum.
// `Debug` is what `CAPTURE(desired, live)` needs in Catch2: a printable form.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DesiredStatus {
    Unchanged,
    Changed,
    NoRecord,
    Removed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LiveStatus {
    Both,
    Desired,
    Recorded,
    Absent,
    Other,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    Conflict,
    ConflictDrift,
    Create,
    Adopt,
    Noop,
    Update,
    Delete,
    /// Links only: not desired, already gone. Drop the record (ADR 0030).
    Forget,
    /// Links only: still desired, removed by hand. Make it again (ADR 0030).
    Recreate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ClassifyResult {
    pub live: LiveStatus,
    pub desired: DesiredStatus,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Link {
    pub target: PathBuf,
    pub dst: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinkRecord {
    pub link: Link,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinkDesired {
    pub link: Link,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinkLive {
    pub link: Link,
}

fn link_match(link_left: &Link, link_right: &Link) -> bool {
    // C++ `assert` only runs in debug builds; `debug_assert!` is the same.
    // (Plain `assert!` in Rust runs in release builds too.)
    debug_assert!(link_left.target.is_absolute());
    debug_assert!(link_left.dst.is_absolute());
    debug_assert!(link_right.target.is_absolute());
    debug_assert!(link_right.dst.is_absolute());
    link_left.target == link_right.target && link_left.dst == link_right.dst
}

// C++ pointers that may be `nullptr` become `Option<&T>`: the compiler makes you
// check for `None` before you can touch the value, so there is no null deref.
//
// C++ overloads `LinkLive::match` for desired and record. Rust has no function
// overloading, so each version gets its own name.
impl LinkLive {
    pub fn match_desired(&self, d: Option<&LinkDesired>) -> bool {
        d.is_some_and(|d| link_match(&self.link, &d.link))
    }
    pub fn match_record(&self, r: Option<&LinkRecord>) -> bool {
        r.is_some_and(|r| link_match(&self.link, &r.link))
    }
}

impl LinkDesired {
    pub fn match_record(&self, r: Option<&LinkRecord>) -> bool {
        r.is_some_and(|r| link_match(&self.link, &r.link))
    }
}

// Explanation of classify, to properly use it.
// Classify the 3 states(desire, record, live):
//   desire is what the to do with the live
//   record indicates the last recorded changes of mdot.
//   live is what currently on disk
//
//   if desire differs from record, then the spec was changed; or the desire is removed:
//     - this is for what to do with the record according to the desired
//     - if desire is removed, record should be forgotten, and live should not exist.
//   get the status based on the desire and record: this is for what to do with the live according to the desired.
//     Both - means, the spec doesnt need to do anything, the spec and record is also Unchanged.
//     Desired - means, the spec and live is the same, its not recorded.
//       - record should be updated to match the live/spec.
//       - mdot failed after linking
//     Recorded - means, the live and recorded is untouched, but the desired was changed
//       - no external process touched the live
//       - mdot has free to do anything with the live.
//     Absent - means, by the word itself, the live is absent
//       - the mdot can create it on that live.
//     Other - means, is neither Desired or Recorded, the live exist but its doesnt matched to the desired or recorded
//    any changes to live should be recorded.
pub fn classify(
    desire: Option<&LinkDesired>,
    record: Option<&LinkRecord>,
    live: Option<&LinkLive>,
) -> ClassifyResult {
    // Matching on a tuple covers all four combinations. The compiler rejects the
    // match if one is missing, so the C++ `assert` becomes an explicit arm.
    let desired = match (desire, record) {
        (Some(d), Some(_)) => {
            if d.match_record(record) {
                DesiredStatus::Unchanged
            } else {
                DesiredStatus::Changed
            }
        }
        (Some(_), None) => DesiredStatus::NoRecord,
        (None, Some(_)) => DesiredStatus::Removed,
        // having record and desire to be null is not a valid case.
        (None, None) => unreachable!("classify: desired and record are both absent"),
    };

    let live = match live {
        None => LiveStatus::Absent,
        Some(live) => {
            let desired = live.match_desired(desire);
            let recorded = live.match_record(record);

            match (desired, recorded) {
                (true, true) => LiveStatus::Both,
                (true, false) => LiveStatus::Desired,
                (false, true) => LiveStatus::Recorded,
                (false, false) => LiveStatus::Other,
            }
        }
    };

    ClassifyResult { live, desired }
}

// `match` must be exhaustive, so the C++ trailing `assert(false); // unreachable`
// isn't needed: adding a DesiredStatus variant makes this a compile error instead.
pub fn generic_decide(c: ClassifyResult) -> Action {
    use DesiredStatus::*;
    use LiveStatus::*;

    match c.desired {
        NoRecord => match c.live {
            Absent => Action::Create,
            Desired => Action::Adopt,
            _ => Action::Conflict,
        },
        Unchanged | Changed => match c.live {
            Both => Action::Noop,
            Recorded => Action::Update,
            _ => Action::ConflictDrift,
        },
        Removed => match c.live {
            Recorded => Action::Delete,
            _ => Action::Conflict,
        },
    }
}

// ---------------------------------------------------------------------------
// The links table (design.typ "Links", ADR 0030; planner.typ
// `links_like_decide`). Every case is written out: no `_` arm, so a case
// nobody decided is a compile error (ADR 0058). The `unreachable!` cells are
// the 7 combinations classify can never produce; reaching one is a bug, and
// panicking is safe because planning has not changed anything yet.

pub fn link_decide(c: ClassifyResult) -> Action {
    use DesiredStatus::*;
    use LiveStatus::*;

    match (c.desired, c.live) {
        // new: no record yet
        (NoRecord, Absent) => Action::Create,
        (NoRecord, Desired) => Action::Adopt,
        (NoRecord, Other) => Action::Conflict,
        (NoRecord, Recorded | Both) => unreachable!("no record, live matches it: {c:?}"),
        // removed: recorded, no longer desired
        (Removed, Absent) => Action::Forget,
        (Removed, Recorded) => Action::Delete,
        (Removed, Other) => Action::Conflict,
        (Removed, Desired | Both) => unreachable!("not desired, live matches desired: {c:?}"),
        // match: desired == recorded
        (Unchanged, Absent) => Action::Recreate,
        (Unchanged, Both) => Action::Noop,
        (Unchanged, Other) => Action::ConflictDrift,
        (Unchanged, Desired | Recorded) => unreachable!("desired == recorded, live matches one: {c:?}"),
        // differ: the spec changed since the record
        (Changed, Absent) => Action::Recreate,
        (Changed, Desired) => Action::Adopt,
        (Changed, Recorded) => Action::Update,
        (Changed, Other) => Action::ConflictDrift,
        (Changed, Both) => unreachable!("desired != recorded, live matches both: {c:?}"),
    }
}

/// What is at a link's `dst` on disk right now.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Observed {
    Absent,
    /// A symlink; the target exactly as stored in the link (`readlink`).
    Symlink(PathBuf),
    File,
    Dir,
    /// A socket, fifo, device...
    Special,
    /// A parent of `dst` is a file, so `dst` can't exist or be made.
    /// TODO(design): not in design.typ; planned as a conflict.
    ParentNotDir,
}

impl Observed {
    /// How a conflict line names it (ADR 0082).
    pub fn describe(&self) -> String {
        match self {
            Observed::Absent => "nothing".to_string(),
            Observed::Symlink(t) => format!("symlink to {}", t.display()),
            Observed::File => "regular file".to_string(),
            Observed::Dir => "directory".to_string(),
            Observed::Special => "special file".to_string(),
            Observed::ParentNotDir => "a parent is not a directory".to_string(),
        }
    }
}

/// `observe` for links: look at `dst` without following it.
pub fn observe_link(dst: &Path) -> Result<Observed, Error> {
    let meta = match fs::symlink_metadata(dst) {
        Ok(m) => m,
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(Observed::Absent),
        Err(e) if e.kind() == ErrorKind::NotADirectory => return Ok(Observed::ParentNotDir),
        Err(e) => return Err(Error::failed(format!("{}: {e}", dst.display()))),
    };
    let ft = meta.file_type();
    Ok(if ft.is_symlink() {
        let target = fs::read_link(dst).map_err(|e| Error::failed(format!("{}: {e}", dst.display())))?;
        Observed::Symlink(target)
    } else if ft.is_dir() {
        Observed::Dir
    } else if ft.is_file() {
        Observed::File
    } else {
        Observed::Special
    })
}

/// One line of the plan: what to do with one resource ID, plus the three
/// sides, so output and apply know what to show and do.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Step {
    pub id: String,
    pub action: Action,
    pub desired: Option<DesiredLink>,
    pub recorded: Option<state::LinkRecord>,
    pub live: Observed,
}

impl Step {
    /// The spec the line belongs under: the desired owner, else the recorded one.
    pub fn spec(&self) -> &str {
        match (&self.desired, &self.recorded) {
            (Some(d), _) => &d.spec,
            (None, Some(r)) => &r.spec,
            (None, None) => unreachable!("a step has a desired or a recorded side"),
        }
    }

    /// The absolute `dst` (same on every side: it is the ID).
    pub fn dst(&self) -> &Path {
        match (&self.desired, &self.recorded) {
            (Some(d), _) => &d.dst,
            (None, Some(r)) => &r.dst,
            (None, None) => unreachable!("a step has a desired or a recorded side"),
        }
    }

    pub fn is_conflict(&self) -> bool {
        matches!(self.action, Action::Conflict | Action::ConflictDrift)
    }

    /// `<what is there>, not managed by mdot` or `..., changed since mdot made
    /// it` (ADR 0082). The output code puts `conflict: <dst>: ` before it.
    pub fn conflict_reason(&self) -> String {
        let whose = if self.recorded.is_some() {
            "changed since mdot made it"
        } else {
            "not managed by mdot"
        };
        format!("{}, {whose}", self.live.describe())
    }
}

/// The order apply runs steps in (ADR 0054): free places first, fill them last.
fn phase(action: Action) -> u8 {
    match action {
        Action::Delete | Action::Forget => 1,
        Action::Create | Action::Recreate => 3,
        _ => 2,
    }
}

/// Matches desired and recorded links by ID, observes each ID once and
/// decides its action (planner.typ "Plan"). Pure except for `observe`:
/// nothing is changed. The steps come back in apply order.
pub fn plan(desired: &[DesiredLink], state: &State) -> Result<Vec<Step>, Error> {
    plan_with(desired, state, observe_link)
}

/// `plan` with a different way to observe live. `preview` passes one that
/// always answers `Absent`: an empty machine (ADR 0071).
///
/// `impl Fn(&Path) -> ...` means "any function or closure with this
/// signature"; the compiler makes one copy of `plan_with` per caller's type.
pub fn plan_with(
    desired: &[DesiredLink],
    state: &State,
    observe: impl Fn(&Path) -> Result<Observed, Error>,
) -> Result<Vec<Step>, Error> {
    // BTreeMap keeps keys sorted, so the union below is in ID order.
    let mut d_by_id: BTreeMap<String, &DesiredLink> = BTreeMap::new();
    for d in desired {
        let id = state::link_id(&d.dst);
        if d_by_id.insert(id.clone(), d).is_some() {
            // The loader's same-dst check runs first; this is a safety net.
            return Err(Error::refused(format!("two desired links for {id}")));
        }
    }
    let r_by_id: BTreeMap<String, &state::LinkRecord> =
        state.links().map(|r| (state::link_id(&r.dst), r)).collect();

    let mut ids: Vec<&String> = d_by_id.keys().chain(r_by_id.keys()).collect();
    ids.sort();
    ids.dedup();

    let mut steps = Vec::new();
    for id in ids {
        let d = d_by_id.get(id).copied();
        let r = r_by_id.get(id).copied();
        let dst = d.map(|d| &d.dst).or(r.map(|r| &r.dst)).expect("id comes from d or r");
        let live = observe(dst)?;

        let desired_side = d.map(|d| LinkDesired { link: Link { target: d.src.clone(), dst: dst.clone() } });
        let record_side = r.map(|r| LinkRecord { link: Link { target: r.src.clone(), dst: dst.clone() } });
        let c = classify_observed(desired_side.as_ref(), record_side.as_ref(), &live, dst);

        steps.push(Step {
            id: id.clone(),
            action: link_decide(c),
            desired: d.cloned(),
            recorded: r.cloned(),
            live,
        });
    }

    // `sort_by_key` is stable and the steps are already in ID order, so this
    // gives "phase, then ID".
    steps.sort_by_key(|s| phase(s.action));
    Ok(steps)
}

/// `classify` takes live as a link. Anything that is not a symlink with an
/// absolute target can never equal an absolute `src`, so it is `Other`.
fn classify_observed(
    d: Option<&LinkDesired>,
    r: Option<&LinkRecord>,
    live: &Observed,
    dst: &Path,
) -> ClassifyResult {
    match live {
        Observed::Absent => classify(d, r, None),
        Observed::Symlink(target) if target.is_absolute() => {
            let l = LinkLive { link: Link { target: target.clone(), dst: dst.to_path_buf() } };
            classify(d, r, Some(&l))
        }
        _ => ClassifyResult { live: LiveStatus::Other, ..classify(d, r, None) },
    }
}
