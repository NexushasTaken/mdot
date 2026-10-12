#pragma once
#include <filesystem>

namespace fs = std::filesystem;

enum struct PlanOperation {
  Create,
  Noop, // No Operation
  Conflict,
  Error,
};

PlanOperation test_link(fs::path src, fs::path dst);

