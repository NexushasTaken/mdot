use mdot::state::{self, LinkRecord, Record, State};
use std::fs;
use std::path::PathBuf;

fn link(spec: &str, dst: &str) -> Record {
    Record::Link(LinkRecord {
        spec: spec.into(),
        src: PathBuf::from(format!("/repo/specs/{spec}/f")),
        dst: PathBuf::from(dst),
    })
}

#[test]
fn missing_file_is_empty_state() {
    let dir = tempfile::tempdir().unwrap();
    assert_eq!(state::load(dir.path()).unwrap(), State::empty());
}

#[test]
fn save_then_load_round_trips() {
    let dir = tempfile::tempdir().unwrap();
    let mut s = State::empty();
    s.repo = Some("/home/u/dotfiles".into());
    s.created_dirs.push("/home/u/.config/foo".into());
    s.put(link("foo", "/home/u/.config/foo/foo.conf"));
    state::save(dir.path(), &s).unwrap();
    assert_eq!(state::load(dir.path()).unwrap(), s);
    assert!(!dir.path().join("state.json.tmp").exists());

    let text = fs::read_to_string(dir.path().join("state.json")).unwrap();
    assert!(text.contains(r#""kind": "link""#), "{text}");
}

#[test]
fn the_design_example_parses() {
    let dir = tempfile::tempdir().unwrap();
    fs::write(
        dir.path().join("state.json"),
        r#"{ "version": 1,
             "repo": "/home/nexus/dotfiles",
             "created_dirs": ["/home/nexus/.config/foo"],
             "resources": [
               { "kind": "link", "spec": "foo",
                 "src": "/home/nexus/dotfiles/specs/foo/foo.conf",
                 "dst": "/home/nexus/.config/foo/foo.conf" } ] }"#,
    )
    .unwrap();
    let s = state::load(dir.path()).unwrap();
    assert_eq!(s.resources[0].id(), "link:/home/nexus/.config/foo/foo.conf");
}

fn load_error(json: &str) -> String {
    let dir = tempfile::tempdir().unwrap();
    fs::write(dir.path().join("state.json"), json).unwrap();
    state::load(dir.path()).unwrap_err().message
}

#[test]
fn bad_files_are_errors() {
    assert!(load_error("{").contains("not valid JSON"));
    assert!(load_error(r#"{"created_dirs": [], "resources": []}"#).contains("no version"));
    assert!(load_error(r#"{"version": 2}"#).contains("upgrade mdot"));
    assert!(load_error(r#"{"version": 1, "created_dirs": [], "resources": [], "x": 1}"#)
        .contains("unknown field"));
    assert!(load_error(r#"{"version": 1, "created_dirs": []}"#).contains("missing field"));
    assert!(load_error(
        r#"{"version": 1, "created_dirs": [], "resources": [{"kind": "pkg", "name": "x"}]}"#
    )
    .contains("unknown variant"));
    assert!(load_error(
        r#"{"version": 1, "created_dirs": [], "resources": [{"kind": "link", "spec": "a", "src": "/a", "dst": "/b", "mode": 1}]}"#
    )
    .contains("unknown field"));
    assert!(load_error(
        r#"{"version": 1, "created_dirs": [], "resources": [
             {"kind": "link", "spec": "a", "src": "/a", "dst": "/b"},
             {"kind": "link", "spec": "b", "src": "/c", "dst": "/b"}]}"#
    )
    .contains("two records for link:/b"));
}

#[test]
fn locks() {
    let base = tempfile::tempdir().unwrap();
    let dir = base.path().join("mdot-data");

    // plan before any apply: no lock file, nothing created.
    let shared = state::lock_shared(&dir).unwrap();
    drop(shared);
    assert!(!dir.exists());

    let excl = state::lock_exclusive(&dir).unwrap();
    assert!(dir.join("lock").exists());
    let e = state::lock_shared(&dir).unwrap_err();
    assert!(e.message.starts_with("another mdot run is using"), "{}", e.message);
    assert!(state::lock_exclusive(&dir).is_err());
    drop(excl);

    let a = state::lock_shared(&dir).unwrap();
    let _b = state::lock_shared(&dir).unwrap();
    assert!(state::lock_exclusive(&dir).is_err());
    drop(a);
}
