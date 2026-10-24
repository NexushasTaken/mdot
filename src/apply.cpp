#include "apply.hpp"
#include "error.hpp"
#include "link.hpp"
#include "spdlog/spdlog.h"
#include "tl/expected.hpp"
#include <format>

namespace mdot {

namespace fs = std::filesystem;

tl::expected<LinkPlan, LinkError> apply_link(fs::path src, fs::path dst) {
  if (src.is_relative()) {
    return LinkError::make_error(src, "must be absolute path");
  }
  if (dst.is_relative()) {
    return LinkError::make_error(dst, "must be absolute path");
  }

  std::error_code ec;
  auto plan_result = plan_link(src, dst);

  if (plan_result) {
    LinkPlan operation = plan_result.value();

    switch (operation.m_operation) {
    case PlanOperation::Create:
      fs::create_directories(plan_result->m_dst.parent_path(), ec);
      if (ec) {
        return LinkError::make_error(plan_result->m_dst.parent_path(), ec);
      }

      fs::create_symlink(plan_result->m_src, plan_result->m_dst, ec);
      if (ec) {
        return LinkError::make_error(std::format("{} -> {}",
                                                 plan_result->m_src.string(),
                                                 plan_result->m_dst.string()),
                                     ec);
      }
      return plan_result;
    case PlanOperation::Conflict:
      return plan_result;
    case PlanOperation::Noop:
      return plan_result;
    }
  }

  return plan_result;
}

} // namespace mdot
