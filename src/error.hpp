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

struct ClauseError {
  std::size_t m_id;
  std::string m_message;
  static tl::unexpected<ClauseError> make_error(std::size_t id,
                                                std::string message);

  std::string string() const;
};
