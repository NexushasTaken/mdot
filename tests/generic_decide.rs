// Port of test/test_generic_decide.cpp. Catch2's GENERATE(table<...>) becomes a
// plain array of tuples and a loop; the assert message plays the role of CAPTURE.
use mdot::planner::{generic_decide, Action, ClassifyResult, DesiredStatus, LiveStatus};

#[test]
fn generic_decide_table() {
    use Action::*;
    use DesiredStatus::*;
    use LiveStatus::*;

    #[rustfmt::skip]
    let table = [
        (NoRecord , Absent  , Create)       ,
        (NoRecord , Desired , Adopt)        ,
        (NoRecord , Other   , Conflict)     ,
        (NoRecord , Both    , Conflict)     ,
        (NoRecord , Recorded, Conflict)     ,

        (Changed  , Both    , Noop)         ,
        (Changed  , Recorded, Update)       ,
        (Changed  , Absent  , ConflictDrift),
        (Changed  , Other   , ConflictDrift),
        (Changed  , Desired , ConflictDrift),

        (Unchanged, Both    , Noop)         ,
        (Unchanged, Recorded, Update)       ,
        (Unchanged, Absent  , ConflictDrift),
        (Unchanged, Other   , ConflictDrift),
        (Unchanged, Desired , ConflictDrift),

        (Removed  , Recorded, Delete)       ,
        (Removed  , Both    , Conflict)     ,
        (Removed  , Absent  , Conflict)     ,
        (Removed  , Other   , Conflict)     ,
        (Removed  , Desired , Conflict)     ,
    ];

    for (desired, live, expected) in table {
        assert_eq!(
            generic_decide(ClassifyResult { live, desired }),
            expected,
            "desired={desired:?} live={live:?}"
        );
    }
}
