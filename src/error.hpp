#pragma once
#include <filesystem>
#include <tl/expected.hpp>

struct Error {
  std::filesystem::path path;
  std::string message;

  std::string string() const { return path.string() + ": " + message; }
};

tl::unexpected<Error> make_error(const std::filesystem::path &path,
                                        std::error_code ec);
tl::unexpected<Error> make_error(const std::filesystem::path &path,
                                        std::string message);
