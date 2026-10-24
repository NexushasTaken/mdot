#pragma once
#include "error.hpp"
#include <filesystem>
#include <tl/expected.hpp>

namespace mdot {

enum struct PlanOperation {
  Create,
  Noop, // No Operation
  Conflict,
};

struct LinkPlan {
  static LinkPlan make_create(std::filesystem::path src,
                              std::filesystem::path dst);
  static LinkPlan make_conflict(std::filesystem::path src, std::string message);
  static LinkPlan make_noop();

  inline bool is_create() noexcept {
    return m_operation == PlanOperation::Create;
  };
  inline bool is_conflict() noexcept {
    return m_operation == PlanOperation::Conflict;
  };
  inline bool is_noop() noexcept { return m_operation == PlanOperation::Noop; };

  std::filesystem::path m_src;
  std::filesystem::path m_dst;

  std::string m_message;
  PlanOperation m_operation;
};

tl::expected<LinkPlan, mdot::LinkError>
plan_link(const std::filesystem::path &src, const std::filesystem::path &dst);

} // namespace mdot
