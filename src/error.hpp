#pragma once
#include <filesystem>
#include <tl/expected.hpp>

struct LinkError {
  std::filesystem::path path;
  std::string message;
  static tl::unexpected<LinkError> make_error(const std::filesystem::path &path,
                                              std::error_code ec);
  static tl::unexpected<LinkError> make_error(const std::filesystem::path &path,
                                              std::string message);

  std::string string() const { return path.string() + ": " + message; }
};
