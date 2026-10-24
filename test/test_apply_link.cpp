#include "apply.hpp"
#include "bw/tempdir/tempdir.hpp"
#include "catch2/catch_test_macros.hpp"
#include <catch2/catch_message.hpp>
#include <filesystem>
#include <fstream>

namespace fs = std::filesystem;
using bw::tempdir::TempDir;

struct CwdGuard {
  fs::path path;
  CwdGuard() : path(fs::current_path()) {}
  ~CwdGuard() { fs::current_path(path); }
};

TEST_CASE("link dst to src", "[apply_link][create-link]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);

  auto r = mdot::apply_link(config_dir, destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);

  REQUIRE(r->is_create());
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(fs::read_symlink(destination_dir) == config_dir);
}

TEST_CASE("link dst to src with missing dst parents directories",
          "[apply_link][missing-parents]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "foo" / "bar" / "destination";

  fs::create_directories(config_dir);

  auto r = mdot::apply_link(config_dir, destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);

  REQUIRE(r->is_create());
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(fs::read_symlink(destination_dir) == config_dir);
}

TEST_CASE("applying twice is Noop", "[apply_link][apply-twice]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);

  {
    auto r = mdot::apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(r);
    REQUIRE(r->is_create());

    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
  {
    auto r = mdot::apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(r);
    REQUIRE(r->is_noop());

    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
}

TEST_CASE("dst is a regular file is conflict", "[apply_link][regular-file]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);
  std::ofstream _regular_file(destination_dir);

  {
    auto r = mdot::apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(r);
    REQUIRE(r->is_conflict());

    REQUIRE(fs::is_regular_file(destination_dir));
  }
}

TEST_CASE("dst is a dangling link", "[apply_link][dangling-link]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";
  fs::path nothing_target = tmp.path() / "nothing";

  fs::create_directories(config_dir);
  fs::create_symlink(nothing_target, destination_dir);
  REQUIRE(fs::is_symlink(destination_dir));

  {
    auto r = mdot::apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(r);
    REQUIRE(r->is_conflict());

    REQUIRE(!fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == nothing_target);
  }
}
