use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

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

// C++ `Step` stores desired/recorded/live by value, so it can't say "absent".
// Here they are `Option`, matching the `nil`s in the Lua pseudocode below.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Step {
    pub id: String,
    pub action: Action,
    pub desired: Option<LinkDesired>,
    pub recorded: Option<LinkRecord>,
    pub live: Option<LinkLive>,
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

// C++ `index_by_id` is a template that works for any T with an `id()` method; the
// requirement is implicit and checked only when instantiated. A Rust generic must
// name the requirement up front as a trait bound (`T: HasId`).
pub trait HasId {
    fn id(&self) -> String;
}

// C++ converts `path` to `std::string` implicitly. A Rust path may not be valid
// UTF-8, so the conversion is explicit (and lossy for invalid bytes).
impl HasId for LinkRecord {
    fn id(&self) -> String {
        self.link.dst.to_string_lossy().into_owned()
    }
}
impl HasId for LinkDesired {
    fn id(&self) -> String {
        self.link.dst.to_string_lossy().into_owned()
    }
}
impl HasId for LinkLive {
    fn id(&self) -> String {
        self.link.dst.to_string_lossy().into_owned()
    }
}

// C++ `std::map<std::string, const T *>`. The `'a` lifetime says the references in
// the map borrow from `items`, so the map can't outlive the vector it points into.
// C++ trusts you on that; Rust checks it.
fn index_by_id<'a, T: HasId>(items: &'a [T]) -> BTreeMap<String, &'a T> {
    let mut map = BTreeMap::new();
    for item in items {
        // C++ `map.insert` keeps the first value on a duplicate key; so does `or_insert`.
        map.entry(item.id()).or_insert(item);
    }
    map
}

// TODO: unfinished, like the C++ version: builds the indexes, returns no steps.
#[allow(unused_variables, unused_mut)]
pub fn plan(desired_items: &[LinkDesired], recorded_items: &[LinkRecord]) -> Vec<Step> {
    let desired_index = index_by_id(desired_items);
    let recorded_index = index_by_id(recorded_items);
    let ids: BTreeSet<String> = BTreeSet::new();

    let mut steps = Vec::new();
    steps
}

/*
function plan(kind, desired_items, recorded_items)
  local D = index_by(kind.id, desired_items)   -- error on a duplicate ID: one owner per ID
  local R = index_by(kind.id, recorded_items)

  local steps = {}
  for _, key in ipairs(sorted(union(keys(D), keys(R)))) do  -- sorted: stable output
    local d, r = D[key], R[key]
    local l    = kind.observe(key)                         -- only known IDs are observed
    local c    = classify(d, r, l, kind.match)
    steps[#steps+1] = { key = key, action = kind.decide(c),
                        desired = d, recorded = r, live = l }
  end
  return steps          -- data only: nothing changed. apply() runs the steps later.
end
*/
