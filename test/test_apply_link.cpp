#include "apply.hpp"
#include "bw/tempdir/tempdir.hpp"
#include "catch2/catch_test_macros.hpp"
#include <catch2/catch_message.hpp>
#include <filesystem>

namespace fs = std::filesystem;
using bw::tempdir::TempDir;

TEST_CASE("link dst to src", "[apply][create-link]") {
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);

  auto r = apply_link(config_dir, destination_dir);

  INFO((r ? "" : r.error().string()));
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(fs::read_symlink(destination_dir) == config_dir);
}

TEST_CASE("link dst to src with missing dst parents directories",
          "[apply][missing-parents]") {
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "foo" / "bar" / "destination";

  fs::create_directories(config_dir);

  auto r = apply_link(config_dir, destination_dir);

  INFO((r ? "" : r.error().string()));
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(fs::read_symlink(destination_dir) == config_dir);
}

TEST_CASE("link dst to src", "[apply][apply-twice]") {
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);

  {
    auto r = apply_link(config_dir, destination_dir);

    INFO((r ? "" : r.error().string()));
    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
  {
    auto r = apply_link(config_dir, destination_dir);

    INFO((r ? "" : r.error().string()));
    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
}

TEST_CASE("dst is a regular file", "[apply][apply-twice]") {
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path destination_dir = tmp.path() / "destination";

  fs::create_directories(config_dir);

  {
    auto r = apply_link(config_dir, destination_dir);

    INFO((r ? "" : r.error().string()));
    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
  {
    auto r = apply_link(config_dir, destination_dir);

    INFO((r ? "" : r.error().string()));
    REQUIRE(fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == config_dir);
  }
}

TEST_CASE("dst is a dangling link", "[apply][dangling-link]") {
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
    REQUIRE(!fs::exists(destination_dir));
    REQUIRE(fs::is_symlink(destination_dir));
    REQUIRE(fs::read_symlink(destination_dir) == nothing_target);
  }
}

TEST_CASE("src is relative", "[apply][relative-src]") {
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path parent_dir = tmp.path() / "foo" / "bar";
  fs::path destination_dir = parent_dir / "destination";

  fs::create_directories(config_dir);
  fs::create_directories(parent_dir);

  fs::current_path(parent_dir);

  auto r = apply_link("../../config", destination_dir);

  INFO((r ? "" : r.error().string()));
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(config_dir == fs::read_symlink(destination_dir));
}

TEST_CASE("src is relative, and applied twice", "[apply][relative-src-applied-twice]") {
  TempDir tmp;

  fs::path config_dir = tmp.path() / "config";
  fs::path parent_dir = tmp.path() / "foo" / "bar";
  fs::path destination_dir = parent_dir / "destination";

  fs::create_directories(config_dir);
  fs::create_directories(parent_dir);

  fs::current_path(parent_dir);

  auto r = apply_link("../../config", destination_dir);
  INFO((r ? "" : r.error().string()));
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(config_dir == fs::read_symlink(destination_dir));

  r = apply_link("../../config", destination_dir);

  REQUIRE(r->is_noop());
  INFO((r ? "" : r.error().string()));
  REQUIRE(fs::exists(destination_dir));
  REQUIRE(fs::is_symlink(destination_dir));
  REQUIRE(config_dir == fs::read_symlink(destination_dir));
}
