#include "spdlog/spdlog.h"
#include <filesystem>
#include "link.hpp"

int main(int argc, char *argv[]) {
  fs::path test_dir = fs::current_path() / "/test/symlink/";

  fs::path src = test_dir / "config.cfg";
  fs::path dst = test_dir / "dst/config.cfg";

  PlanOperation op = test_link(src, dst);

  switch (op) {
  case PlanOperation::Create:
    spdlog::info("Create");
    break;
  case PlanOperation::Noop:
    spdlog::info("Noop");
    break;
  case PlanOperation::Conflict:
    spdlog::info("Conflict");
    break;
  }

  // spdlog::info("Hello, World!");
  // plan_link("gdbinit", "~/.config/gdb/gdbinit");
  return 0;
}
