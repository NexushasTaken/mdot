#include "apply.hpp"
#include "error.hpp"
#include "link.hpp"
#include "spdlog/spdlog.h"
#include "tl/expected.hpp"
#include <format>

namespace fs = std::filesystem;

tl::expected<LinkPlan, Error> apply_link(fs::path src, fs::path dst) {
  std::error_code ec;
  auto plan_result = plan_link(src, dst);

  if (plan_result) {
    LinkPlan operation = plan_result.value();

    switch (operation.m_operation) {
    case PlanOperation::Create:
      fs::create_directories(plan_result->m_dst.parent_path(), ec);
      if (ec) {
        return make_error(plan_result->m_dst.parent_path(), ec);
      }

      fs::create_symlink(plan_result->m_src, plan_result->m_dst, ec);
      if (ec) {
        return make_error(std::format("{} -> {}", plan_result->m_src.string(),
                                      plan_result->m_dst.string()),
                          ec);
      }
      return plan_result;
    case PlanOperation::Conflict:
      return plan_result;
    case PlanOperation::Noop:
      return plan_result;
    }
  } else {
    return make_error(dst, plan_result.error().string());
  }

  return plan_result;
}
