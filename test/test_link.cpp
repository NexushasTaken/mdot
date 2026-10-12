#include "bw/tempdir/tempdir.hpp"
#include "catch2/catch_test_macros.hpp"
#include "link.hpp"
#include <filesystem>

using bw::tempdir::TempDir;

TEST_CASE("src doesn't exist means Error") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  REQUIRE(test_link(config_path, destination_path) == PlanOperation::Error);
}

TEST_CASE("nothing at dst means Create") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);

  REQUIRE(test_link(config_path, destination_path) == PlanOperation::Create);
}

TEST_CASE("dst symlink points to src means Noop") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);

  fs::create_symlink(config_path, destination_path);

  REQUIRE(test_link(config_path, destination_path) == PlanOperation::Noop);
}

TEST_CASE("dst is a dangling symlink means Conflict") {
  TempDir tmp;

  auto nothing_path = tmp.path() / "nothing";
  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);
  fs::create_symlink(nothing_path, destination_path);

  REQUIRE(test_link(config_path, destination_path) == PlanOperation::Conflict);
}

TEST_CASE("dst is not a symlink to src means Conflict") {
  TempDir tmp;

  auto different_path = tmp.path() / "nothing";
  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);
  fs::create_directory(different_path);

  fs::create_symlink(different_path, destination_path);

  REQUIRE(test_link(config_path, destination_path) == PlanOperation::Conflict);
}
