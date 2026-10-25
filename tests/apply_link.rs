// Port of test/test_apply_link.cpp. The C++ `CwdGuard` is left out: apply_link never
// changes the working directory, and Rust runs tests in parallel threads that share
// one cwd, so tests that change it would race each other anyway.
use mdot::apply::apply_link;
use mdot::common::create_symlink;
use std::fs;
use tempfile::TempDir;

#[test]
fn link_dst_to_src() {
    let tmp = TempDir::new().unwrap();

    let config_dir = tmp.path().join("config");
    let destination_dir = tmp.path().join("destination");

    fs::create_dir_all(&config_dir).unwrap();

    let r = apply_link(&config_dir, &destination_dir).unwrap();

    assert!(r.is_create(), "{r:?}");
    assert!(destination_dir.exists());
    assert!(destination_dir.is_symlink());
    assert_eq!(fs::read_link(&destination_dir).unwrap(), config_dir);
}

#[test]
fn link_dst_to_src_with_missing_dst_parent_directories() {
    let tmp = TempDir::new().unwrap();

    let config_dir = tmp.path().join("config");
    let destination_dir = tmp.path().join("foo").join("bar").join("destination");

    fs::create_dir_all(&config_dir).unwrap();

    let r = apply_link(&config_dir, &destination_dir).unwrap();

    assert!(r.is_create(), "{r:?}");
    assert!(destination_dir.exists());
    assert!(destination_dir.is_symlink());
    assert_eq!(fs::read_link(&destination_dir).unwrap(), config_dir);
}

#[test]
fn applying_twice_is_noop() {
    let tmp = TempDir::new().unwrap();

    let config_dir = tmp.path().join("config");
    let destination_dir = tmp.path().join("destination");

    fs::create_dir_all(&config_dir).unwrap();

    {
        let r = apply_link(&config_dir, &destination_dir).unwrap();
        assert!(r.is_create(), "{r:?}");

        assert!(destination_dir.exists());
        assert!(destination_dir.is_symlink());
        assert_eq!(fs::read_link(&destination_dir).unwrap(), config_dir);
    }
    {
        let r = apply_link(&config_dir, &destination_dir).unwrap();
        assert!(r.is_noop(), "{r:?}");

        assert!(destination_dir.exists());
        assert!(destination_dir.is_symlink());
        assert_eq!(fs::read_link(&destination_dir).unwrap(), config_dir);
    }
}

#[test]
fn dst_is_a_regular_file_is_conflict() {
    let tmp = TempDir::new().unwrap();

    let config_dir = tmp.path().join("config");
    let destination_dir = tmp.path().join("destination");

    fs::create_dir_all(&config_dir).unwrap();
    fs::File::create(&destination_dir).unwrap();

    let r = apply_link(&config_dir, &destination_dir).unwrap();
    assert!(r.is_conflict(), "{r:?}");

    assert!(destination_dir.is_file());
}

#[test]
fn dst_is_a_dangling_link() {
    let tmp = TempDir::new().unwrap();

    let config_dir = tmp.path().join("config");
    let destination_dir = tmp.path().join("destination");
    let nothing_target = tmp.path().join("nothing");

    fs::create_dir_all(&config_dir).unwrap();
    create_symlink(&nothing_target, &destination_dir).unwrap();
    assert!(destination_dir.is_symlink());

    let r = apply_link(&config_dir, &destination_dir).unwrap();
    assert!(r.is_conflict(), "{r:?}");

    assert!(!destination_dir.exists());
    assert!(destination_dir.is_symlink());
    assert_eq!(fs::read_link(&destination_dir).unwrap(), nothing_target);
}
