// Port of test/test_classify.cpp. `nullptr` arguments become `None`,
// `&d` becomes `Some(&d)`.
use mdot::planner::{classify, DesiredStatus, Link, LinkDesired, LinkLive, LinkRecord, LiveStatus};
use std::path::PathBuf;

const DST: &str = "/config"; // acts as an ID
const A: &str = "/specs/config";
const B: &str = "/specs/.config";
const C: &str = "/specs/conf";

fn link(target: &str) -> Link {
    Link {
        target: PathBuf::from(target),
        dst: PathBuf::from(DST),
    }
}

#[test]
fn all_state_are_the_same() {
    let d = LinkDesired { link: link(A) };
    let r = LinkRecord { link: link(A) };
    let l = LinkLive { link: link(A) };

    let res = classify(Some(&d), Some(&r), Some(&l));
    assert_eq!(res.live, LiveStatus::Both);
    assert_eq!(res.desired, DesiredStatus::Unchanged);
}

#[test]
fn new_spec_no_record_live() {
    let d = LinkDesired { link: link(A) };

    let res = classify(Some(&d), None, None);
    assert_eq!(res.live, LiveStatus::Absent);
    assert_eq!(res.desired, DesiredStatus::NoRecord);
}

#[test]
fn update_live_and_record() {
    let d = LinkDesired { link: link(B) };
    let r = LinkRecord { link: link(A) };
    let l = LinkLive { link: link(A) };

    let res = classify(Some(&d), Some(&r), Some(&l));
    assert_eq!(res.live, LiveStatus::Recorded);
    assert_eq!(res.desired, DesiredStatus::Changed);
}

#[test]
fn possible_conflict() {
    let d = LinkDesired { link: link(A) };
    let r = LinkRecord { link: link(A) };
    let l = LinkLive { link: link(B) };

    let res = classify(Some(&d), Some(&r), Some(&l));
    assert_eq!(res.live, LiveStatus::Other);
    assert_eq!(res.desired, DesiredStatus::Unchanged);
}

#[test]
fn record_needs_to_be_updated() {
    let d = LinkDesired { link: link(A) };
    let r = LinkRecord { link: link(B) };
    let l = LinkLive { link: link(A) };

    let res = classify(Some(&d), Some(&r), Some(&l));
    assert_eq!(res.live, LiveStatus::Desired);
    assert_eq!(res.desired, DesiredStatus::Changed);
}

#[test]
fn record_needs_to_be_set() {
    let d = LinkDesired { link: link(A) };
    let l = LinkLive { link: link(A) };

    let res = classify(Some(&d), None, Some(&l));
    assert_eq!(res.live, LiveStatus::Desired);
    assert_eq!(res.desired, DesiredStatus::NoRecord);
}

#[test]
fn no_record_but_live_differs_from_desired() {
    let d = LinkDesired { link: link(A) };
    let l = LinkLive { link: link(B) };

    let res = classify(Some(&d), None, Some(&l));
    assert_eq!(res.live, LiveStatus::Other);
    assert_eq!(res.desired, DesiredStatus::NoRecord);
}

#[test]
fn removed_spec() {
    let r = LinkRecord { link: link(A) };
    let l = LinkLive { link: link(A) };

    let res = classify(None, Some(&r), Some(&l));
    assert_eq!(res.live, LiveStatus::Recorded);
    assert_eq!(res.desired, DesiredStatus::Removed);
}

#[test]
fn no_desired_and_live() {
    let r = LinkRecord { link: link(A) };

    let res = classify(None, Some(&r), None);
    assert_eq!(res.live, LiveStatus::Absent);
    assert_eq!(res.desired, DesiredStatus::Removed);
}

#[test]
fn no_desire_but_live_differs_from_record() {
    let r = LinkRecord { link: link(A) };
    let l = LinkLive { link: link(B) };

    let res = classify(None, Some(&r), Some(&l));
    assert_eq!(res.live, LiveStatus::Other);
    assert_eq!(res.desired, DesiredStatus::Removed);
}

#[test]
fn unchanged_desire_but_live_is_absent() {
    let d = LinkDesired { link: link(A) };
    let r = LinkRecord { link: link(A) };

    let res = classify(Some(&d), Some(&r), None);
    assert_eq!(res.live, LiveStatus::Absent);
    assert_eq!(res.desired, DesiredStatus::Unchanged);
}

#[test]
fn desire_differs_from_record_but_live_is_absent() {
    let d = LinkDesired { link: link(A) };
    let r = LinkRecord { link: link(B) };

    let res = classify(Some(&d), Some(&r), None);
    assert_eq!(res.live, LiveStatus::Absent);
    assert_eq!(res.desired, DesiredStatus::Changed);
}

#[test]
fn desire_record_and_live_differs() {
    let d = LinkDesired { link: link(A) };
    let r = LinkRecord { link: link(B) };
    let l = LinkLive { link: link(C) };

    let res = classify(Some(&d), Some(&r), Some(&l));
    assert_eq!(res.live, LiveStatus::Other);
    assert_eq!(res.desired, DesiredStatus::Changed);
}

// New: the C++ version can't test its `assert`, because it aborts the process.
// A Rust panic is catchable per test with `#[should_panic]`.
#[test]
#[should_panic(expected = "both absent")]
fn desired_and_record_both_absent_panics() {
    classify(None, None, None);
}
