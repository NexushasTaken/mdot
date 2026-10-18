#pragma once
#include <filesystem>
#include <tl/expected.hpp>

enum struct PlanOperation {
  Create,
  Noop, // No Operation
  Conflict,
};

struct Error {
  std::filesystem::path path;
  std::string message;

  std::string string() const { return path.string() + ": " + message; }
};

tl::expected<PlanOperation, Error> plan_link(std::filesystem::path src,
                                             std::filesystem::path dst);
