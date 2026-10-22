#include "common.hpp"
#include "sago/platform_folders.h"
#include "tl/expected.hpp"
#include <cstdlib>
#include <exception>
#include <filesystem>

namespace fs = std::filesystem;

fs::path clean_path(const fs::path &path) {
  if (!path.lexically_normal().has_filename()) {
    return path.parent_path();
  }
  return path;
}

tl::expected<fs::path, std::string> normalize_path(const fs::path &path) {
  std::error_code ec;
  fs::path new_path = path.lexically_normal();
  if (path.is_relative()) {
    auto current_path = fs::current_path(ec);
    if (ec) {
      return tl::make_unexpected(ec.message());
    }

    auto real = (current_path / path).lexically_normal();
    return clean_path(real);
  }
  return clean_path(path.lexically_normal());
}

tl::expected<fs::path, std::string> expand_home(const fs::path &path) {
  if (path.empty()) {
    return path;
  }
  if (*path.begin() == "~") {
    fs::path home;

    try {
      home = sago::internal::getHome();
    } catch (const std::exception &e) {
      return tl::make_unexpected(e.what());
    }

    return home / path.lexically_relative("~");
  }
  return path;
}

tl::expected<fs::path, std::string> resolve_path(const fs::path &path) {
  return expand_home(path).and_then(normalize_path);
}
