use mdot::loader::DesiredLink;
use mdot::planner::{link_decide, plan, Action, ClassifyResult, DesiredStatus, LiveStatus, Observed};
use mdot::state::{LinkRecord, Record, State};
use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};

/// The 13 cases of planner.typ against ADR 0030's table.
#[test]
fn link_decide_covers_the_13_cases() {
    use Action::*;
    use DesiredStatus::*;
    use LiveStatus::*;

    #[rustfmt::skip]
    let table = [
        (NoRecord,  Absent,   Create),
        (NoRecord,  Desired,  Adopt),
        (NoRecord,  Other,    Conflict),
        (Removed,   Absent,   Forget),
        (Removed,   Recorded, Delete),
        (Removed,   Other,    Conflict),
        (Unchanged, Absent,   Recreate),
        (Unchanged, Both,     Noop),
        (Unchanged, Other,    ConflictDrift),
        (Changed,   Absent,   Recreate),
        (Changed,   Desired,  Adopt),
        (Changed,   Recorded, Update),
        (Changed,   Other,    ConflictDrift),
    ];
    for (desired, live, expected) in table {
        let got = link_decide(ClassifyResult { desired, live });
        assert_eq!(got, expected, "{desired:?} / {live:?}");
    }
}

struct World {
    _tmp: tempfile::TempDir,
    root: PathBuf,
}

impl World {
    fn new() -> World {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().to_path_buf();
        fs::create_dir_all(root.join("repo")).unwrap();
        fs::create_dir_all(root.join("home")).unwrap();
        World { _tmp: tmp, root }
    }
    fn src(&self, name: &str) -> PathBuf {
        self.root.join("repo").join(name)
    }
    fn dst(&self, name: &str) -> PathBuf {
        self.root.join("home").join(name)
    }
    fn want(&self, src: &str, dst: &str) -> DesiredLink {
        DesiredLink {
            spec: "s".into(),
            src: self.src(src),
            dst: self.dst(dst),
            src_shown: src.into(),
            dst_shown: format!("~/{dst}"),
        }
    }
    fn record(&self, src: &str, dst: &str) -> Record {
        Record::Link(LinkRecord { spec: "s".into(), src: self.src(src), dst: self.dst(dst) })
    }
    fn link_on_disk(&self, src: &str, dst: &str) {
        symlink(self.src(src), self.dst(dst)).unwrap();
    }
}

fn state_of(records: Vec<Record>) -> State {
    let mut s = State::empty();
    for r in records {
        s.put(r);
    }
    s
}

fn actions(steps: &[mdot::planner::Step], root: &Path) -> Vec<(String, Action)> {
    steps
        .iter()
        .map(|s| {
            let name = s.dst().strip_prefix(root.join("home")).unwrap().display().to_string();
            (name, s.action)
        })
        .collect()
}

#[test]
fn every_link_row_on_a_real_disk() {
    let w = World::new();
    // create: desired, nothing there
    // adopt (new): desired, link already right
    w.link_on_disk("a", "adopt");
    // conflict: desired, a regular file there
    fs::write(w.dst("file"), "").unwrap();
    // noop: desired == recorded == live
    w.link_on_disk("a", "noop");
    // update: spec changed a -> b, disk still a
    w.link_on_disk("a", "update");
    // recreate: recorded and desired, removed by hand
    // adopt (differ): spec changed a -> b, disk already b
    w.link_on_disk("b", "adopt2");
    // drift: recorded a, someone pointed it elsewhere
    w.link_on_disk("x", "drift");
    // delete: recorded, not desired, still ours
    w.link_on_disk("a", "delete");
    // forget: recorded, not desired, already gone
    // removed conflict: recorded, not desired, now a directory
    fs::create_dir(w.dst("gone-dir")).unwrap();

    let desired = vec![
        w.want("a", "create"),
        w.want("a", "adopt"),
        w.want("a", "file"),
        w.want("a", "noop"),
        w.want("b", "update"),
        w.want("a", "recreate"),
        w.want("b", "adopt2"),
        w.want("a", "drift"),
    ];
    let state = state_of(vec![
        w.record("a", "noop"),
        w.record("a", "update"),
        w.record("a", "recreate"),
        w.record("a", "adopt2"),
        w.record("a", "drift"),
        w.record("a", "delete"),
        w.record("a", "forget"),
        w.record("a", "gone-dir"),
    ]);

    let steps = plan(&desired, &state).unwrap();
    use Action::*;
    let expected: Vec<(String, Action)> = [
        // phase 1, by ID
        ("delete", Delete),
        ("forget", Forget),
        // phase 2
        ("adopt", Adopt),
        ("adopt2", Adopt),
        ("drift", ConflictDrift),
        ("file", Conflict),
        ("gone-dir", Conflict),
        ("noop", Noop),
        ("update", Update),
        // phase 3
        ("create", Create),
        ("recreate", Recreate),
    ]
    .iter()
    .map(|(n, a)| (n.to_string(), *a))
    .collect();
    assert_eq!(actions(&steps, &w.root), expected);

    let reason = |name: &str| {
        steps.iter().find(|s| s.dst() == w.dst(name)).unwrap().conflict_reason()
    };
    assert_eq!(reason("file"), "regular file, not managed by mdot");
    assert_eq!(reason("gone-dir"), "directory, changed since mdot made it");
    assert_eq!(
        reason("drift"),
        format!("symlink to {}, changed since mdot made it", w.src("x").display())
    );
}

#[test]
fn a_relative_link_is_never_a_match() {
    let w = World::new();
    symlink("../repo/a", w.dst("rel")).unwrap();
    let steps = plan(&[w.want("a", "rel")], &State::empty()).unwrap();
    assert_eq!(steps[0].action, Action::Conflict);
    assert_eq!(steps[0].live, Observed::Symlink("../repo/a".into()));
}

#[test]
fn a_file_parent_is_a_conflict() {
    let w = World::new();
    fs::write(w.dst("f"), "").unwrap();
    let steps = plan(&[w.want("a", "f/x")], &State::empty()).unwrap();
    assert_eq!(steps[0].action, Action::Conflict);
    assert_eq!(steps[0].live, Observed::ParentNotDir);
}
