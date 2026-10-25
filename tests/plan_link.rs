// Port of test/test_plan_link.cpp. Catch2's TEST_CASE becomes a plain `#[test]` fn;
// `tempfile::TempDir` deletes itself when it goes out of scope (Drop = destructor),
// like bw::tempdir::TempDir.
use mdot::common::create_symlink;
use mdot::link::plan_link;
use std::fs;
use tempfile::TempDir;

#[test]
fn src_doesnt_exist_means_error() {
    let tmp = TempDir::new().unwrap();

    let config_path = tmp.path().join("config");
    let destination_path = tmp.path().join("destination");

    let p = plan_link(&config_path, &destination_path);
    assert!(p.is_err(), "{p:?}");
}

#[test]
fn nothing_at_dst_means_create() {
    let tmp = TempDir::new().unwrap();

    let config_path = tmp.path().join("config");
    let destination_path = tmp.path().join("destination");

    fs::create_dir(&config_path).unwrap();

    // `.unwrap()` on Err panics and prints the error: INFO + REQUIRE in one.
    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_create(), "{p:?}");
}

#[test]
fn dst_symlink_to_src_means_noop() {
    let tmp = TempDir::new().unwrap();

    let config_path = tmp.path().join("config");
    let destination_path = tmp.path().join("destination");

    fs::create_dir(&config_path).unwrap();
    create_symlink(&config_path, &destination_path).unwrap();

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_noop(), "{p:?}");
}

#[test]
fn dst_relatively_symlink_to_src_means_noop() {
    let tmp = TempDir::new().unwrap();

    let parent_path = tmp.path().join("foo").join("bar");
    fs::create_dir_all(&parent_path).unwrap();

    let config_path = tmp.path().join("config");
    let destination_path = parent_path.join("destination");

    fs::create_dir(&config_path).unwrap();
    create_symlink("../../config".as_ref(), &destination_path).unwrap();

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_noop(), "{p:?}");
}

#[test]
fn dst_is_a_dangling_symlink_means_conflict() {
    let tmp = TempDir::new().unwrap();

    let nothing_path = tmp.path().join("nothing");
    let config_path = tmp.path().join("config");
    let destination_path = tmp.path().join("destination");

    fs::create_dir(&config_path).unwrap();
    create_symlink(&nothing_path, &destination_path).unwrap();

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_conflict(), "{p:?}");
}

#[test]
fn dst_is_not_a_symlink_to_src_means_conflict() {
    let tmp = TempDir::new().unwrap();

    let different_path = tmp.path().join("nothing");
    let config_path = tmp.path().join("config");
    let destination_path = tmp.path().join("destination");

    fs::create_dir(&config_path).unwrap();
    fs::create_dir(&different_path).unwrap();
    create_symlink(&different_path, &destination_path).unwrap();

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_conflict(), "{p:?}");
}

#[test]
fn dst_parent_doesnt_exist_means_create() {
    let tmp = TempDir::new().unwrap();

    let parent_path = tmp.path().join("parent");

    let config_path = tmp.path().join("config");
    fs::create_dir(&config_path).unwrap();

    let destination_path = parent_path.join("destination");

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_create(), "{p:?}");
}

#[test]
fn dst_parent_2_level_deep_doesnt_exist_means_create() {
    let tmp = TempDir::new().unwrap();

    let parent_path = tmp.path().join("one").join("two");

    let config_path = tmp.path().join("config");
    fs::create_dir(&config_path).unwrap();

    let destination_path = parent_path.join("destination");

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_create(), "{p:?}");
}

#[test]
fn dst_parent_is_a_regular_file_means_conflict() {
    let tmp = TempDir::new().unwrap();

    let parent_path = tmp.path().join("parent");
    fs::File::create(&parent_path).unwrap();

    let config_path = tmp.path().join("config");
    fs::create_dir(&config_path).unwrap();

    let destination_path = parent_path.join("destination");

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_conflict(), "{p:?}");
}

#[test]
fn dst_is_a_regular_file_means_conflict() {
    let tmp = TempDir::new().unwrap();

    let config_path = tmp.path().join("config");
    let destination_path = tmp.path().join("destination");

    fs::create_dir_all(&config_path).unwrap();
    fs::File::create(&destination_path).unwrap();

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_conflict(), "{p:?}");
}

#[test]
fn dst_is_a_directory_means_conflict() {
    let tmp = TempDir::new().unwrap();

    let config_path = tmp.path().join("config");
    let destination_path = tmp.path().join("destination");

    fs::create_dir_all(&config_path).unwrap();
    fs::create_dir_all(&destination_path).unwrap();

    let p = plan_link(&config_path, &destination_path).unwrap();
    assert!(p.is_conflict(), "{p:?}");
}
