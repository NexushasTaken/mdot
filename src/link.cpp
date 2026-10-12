#include "link.hpp"
#include <filesystem>

PlanOperation test_link(fs::path src, fs::path dst) {
  if (!fs::exists(src)) {
    return PlanOperation::Error;
  }

  if (fs::is_regular_file(dst)) {
    return PlanOperation::Conflict;
  }

  if (fs::is_symlink(dst)) {
    auto realpath = fs::absolute(fs::read_symlink(dst));

    if (realpath == src) {
      return PlanOperation::Noop;
    } else {
      return PlanOperation::Conflict;
    }
  }

  return PlanOperation::Create;
}
