#include "common.hpp"
#include "tl/expected.hpp"
#include <filesystem>

namespace fs = std::filesystem;

fs::path clean_path(const fs::path &path) {
  if (!path.lexically_normal().has_filename()) {
    return path.parent_path();
  }
  return path;
}

tl::expected<fs::path, std::error_code> normalize_path(const fs::path &path) {
  std::error_code ec;
  fs::path new_path = path.lexically_normal();
  if (path.is_relative()) {
    auto current_path = fs::current_path(ec);
    if (ec) {
      return tl::make_unexpected(ec);
    }

    auto real = (current_path / path).lexically_normal();
    return clean_path(real);
  }
  return clean_path(path.lexically_normal());
}
