#pragma once
#include "error.hpp"
#include <filesystem>
#include <format>
#include <tl/expected.hpp>

struct PlanOperation {
  enum Operation {
    Create,
    Noop, // No Operation
    Conflict,
  };

  static PlanOperation make_create(std::filesystem::path src,
                                   std::filesystem::path dst);
  static PlanOperation make_conflict(std::filesystem::path src,
                                     std::string message);
  static PlanOperation make_noop();

  inline bool is_create() noexcept { return m_operation == Create; };
  inline bool is_conflict() noexcept { return m_operation == Conflict; };
  inline bool is_noop() noexcept { return m_operation == Noop; };

  std::filesystem::path m_src;
  std::filesystem::path m_dst;

  std::string m_message;
  Operation m_operation;
};

tl::expected<PlanOperation, Error> plan_link(const std::filesystem::path &src,
                                             const std::filesystem::path &dst);
