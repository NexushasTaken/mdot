#include "link.hpp"
#include "spdlog/spdlog.h"
#include "tl/expected.hpp"
#include <filesystem>
#include <tl/expected.hpp>

int main(int argc, char *argv[]) {
  std::filesystem::path path_a = "/usr/./bin/.";
  std::filesystem::path path_b = "/usr/bin";
  // spdlog::info("{}", from.string());
  // spdlog::info("{}", from.parent_path().string());
  // spdlog::info("{}", from.parent_path().parent_path().string());
  // spdlog::info("{}", from.parent_path().parent_path().has_stem());
  // spdlog::info("{}", from.parent_path().has_stem());
  auto lpath_a = path_a.lexically_normal();
  auto lpath_b = path_b.lexically_normal();
  spdlog::info("{}\n", lpath_a.string());
  spdlog::info("{}\n", lpath_b.string());
  if (!lpath_a.has_filename()) {
    lpath_a = lpath_a.parent_path();
  }
  spdlog::info("{}\n", lpath_a == lpath_b);
  spdlog::info("{}\n", lpath_a.compare(lpath_b));

  /*
  ```
  (gdb) p link_target
  $3 = filesystem::path "/tmp/temp_dir_1792307939600_15012/config" = {
    [root-directory] = "/",
    [1] = "tmp",
    [2] = "temp_dir_1792307939600_15012",
    [3] = "config"
  }
  (gdb) p src
  $4 = filesystem::path "/tmp/temp_dir_1792307939600_15012/config/" = {
    [root-directory] = "/",
    [1] = "tmp",
    [2] = "temp_dir_1792307939600_15012",
    [3] = "config",
    [4] = ""
  }
  ```
  */

  return 0;
}
