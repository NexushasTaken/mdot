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

TEST_CASE("link dst to src", "[apply][create-link]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);

  auto r = apply_link(config_dir, destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);

  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(fs::read_symlink(destination_dir) == config_dir);
}

TEST_CASE("link dst to src with missing dst parents directories",
          "[apply][missing-parents]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "foo" / "bar" / "destination";

  fs::create_directories(config_dir);

  auto r = apply_link(config_dir, destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);

  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(fs::read_symlink(destination_dir) == config_dir);
}

TEST_CASE("applying twice is Noop", "[apply][apply-twice]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);

  {
    auto r = apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(r);
    REQUIRE(r->is_create());

    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
  {
    auto r = apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(r);
    REQUIRE(r->is_noop());

    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
}

TEST_CASE("dst is a regular file is conflict", "[apply][regular-file]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);
  std::ofstream _regular_file(destination_dir);

  {
    auto r = apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(!r);

    REQUIRE(fs::is_regular_file(destination_dir));
  }
}

TEST_CASE("dst is a dangling link", "[apply][dangling-link]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";
  fs::path nothing_target = tmp.path() / "nothing";

  fs::create_directories(config_dir);
  fs::create_symlink(nothing_target, destination_dir);
  REQUIRE(fs::is_symlink(destination_dir));

  {
    auto r = apply_link(config_dir, destination_dir);
    INFO((r ? "" : r.error().string()));
    REQUIRE(!r);

    REQUIRE(!fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == nothing_target);
  }
}

TEST_CASE("src is relative, and applied twice",
          "[apply][relative-src-applied-twice]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path parent_dir = tmp.path() / "foo" / "bar";
  fs::path destination_dir = parent_dir / "destination";

  fs::create_directories(config_dir);
  fs::create_directories(parent_dir);

  fs::current_path(parent_dir);

  auto r = apply_link("../../config", destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);

  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(config_dir == fs::read_symlink(destination_dir));

  r = apply_link("../../config", destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);

  REQUIRE(r->is_noop());
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(config_dir == fs::read_symlink(destination_dir));
}

TEST_CASE("relative src from a cwd that isn't dst's parent",
          "[apply][relative-src-other-cwd]") {
  CwdGuard f;
  TempDir tmp;

  fs::path config_dir = "config";
  fs::path destination_dir = tmp.path() / "foo" / "destination";
  fs::current_path(tmp.path());
  fs::create_directories(config_dir);

  auto r = apply_link(config_dir, destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);
  REQUIRE(r->is_create());
  REQUIRE(fs::exists(destination_dir));

  r = apply_link(config_dir, destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(r);
  REQUIRE(r->is_noop());
  REQUIRE(fs::exists(destination_dir));
}
