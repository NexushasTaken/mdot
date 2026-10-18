#include "bw/tempdir/tempdir.hpp"
#include "catch2/catch_test_macros.hpp"
#include "link.hpp"
#include <catch2/catch_message.hpp>
#include <filesystem>
#include <fstream>

namespace fs = std::filesystem;
using bw::tempdir::TempDir;

TEST_CASE("src doesn't exist means Error") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  auto p = plan_link(config_path, destination_path);

  INFO((p ? "" : p.error().string()));
  REQUIRE(!p.has_value());
}

TEST_CASE("nothing at dst means Create") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Create);
}

TEST_CASE("dst symlink to src means Noop") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);

  fs::create_symlink(config_path, destination_path);

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Noop);
}

TEST_CASE("dst relatively symlink to src means Noop") {
  TempDir tmp;

  auto parent_path = tmp.path() / "foo" / "bar";
  fs::create_directories(parent_path);

  auto config_path = tmp.path() / "config";
  auto destination_path = parent_path / "destination";

  fs::create_directory(config_path);

  fs::create_symlink("../../config", destination_path);

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Noop);
}

TEST_CASE("dst is a dangling symlink means Conflict") {
  TempDir tmp;

  auto nothing_path = tmp.path() / "nothing";
  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);
  fs::create_symlink(nothing_path, destination_path);

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Conflict);
}

TEST_CASE("dst is not a symlink to src means Conflict") {
  TempDir tmp;

  auto different_path = tmp.path() / "nothing";
  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directory(config_path);
  fs::create_directory(different_path);

  fs::create_symlink(different_path, destination_path);

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Conflict);
}

TEST_CASE("dst parent doesn't exist means Create") {
  TempDir tmp;

  auto parent_path = tmp.path() / "parent";

  auto config_path = tmp.path() / "config";
  fs::create_directory(config_path);

  auto destination_path = parent_path / "destination";

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Create);
}

TEST_CASE("dst parent 2-level deep doesn't exist means Create", "[2-level]") {
  TempDir tmp;

  auto parent_path = tmp.path() / "one" / "two";

  auto config_path = tmp.path() / "config";
  fs::create_directory(config_path);

  auto destination_path = parent_path / "destination";

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Create);
}

TEST_CASE("dst parent is a regular file means Conflict", "[regular_file]") {
  TempDir tmp;

  auto parent_path = tmp.path() / "parent";
  std::ofstream _regular_file(parent_path.string());
  REQUIRE(_regular_file.is_open());

  auto config_path = tmp.path() / "config";
  fs::create_directory(config_path);

  auto destination_path = parent_path / "destination";

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));

  REQUIRE(p.value() == PlanOperation::Conflict);
}

TEST_CASE("src has '/.' suffix means Noop", "[current-dir-suffix]") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directories(config_path);
  fs::create_symlink(config_path, destination_path);

  auto p = plan_link(config_path / ".", destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Noop);
}

TEST_CASE("dst is a regular file means Conflict", "[regular-file]") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directories(config_path);
  std::ofstream _regular_file(destination_path);
  REQUIRE(_regular_file.is_open());

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Conflict);
}

TEST_CASE("dst is a directory means Conflict", "[regular-file]") {
  TempDir tmp;

  auto config_path = tmp.path() / "config";
  auto destination_path = tmp.path() / "destination";

  fs::create_directories(config_path);
  fs::create_directories(destination_path);

  auto p = plan_link(config_path, destination_path);
  INFO((p ? "" : p.error().string()));
  REQUIRE(p.value() == PlanOperation::Conflict);
}
