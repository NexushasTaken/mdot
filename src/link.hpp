#pragma once
#include "error.hpp"
#include <filesystem>
#include <format>
#include <sol/table.hpp>
#include <tl/expected.hpp>

enum struct PlanOperation {
  Create,
  Noop, // No Operation
  Conflict,
};

struct ClauseError {
  std::size_t m_id;
  std::string m_message;
  static tl::unexpected<ClauseError> make_error(std::size_t id,
                                                std::string message);

  std::string string() const {
    return std::format("entry {}: {}", m_id, m_message);
  }
};

struct LinkClause {
  std::string m_src;
  std::string m_dst;

  static tl::expected<LinkClause, ClauseError>
  from_table(std::size_t id, sol::table raw_clause);
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

tl::expected<LinkPlan, LinkError> plan_link(const std::filesystem::path &src,
                                            const std::filesystem::path &dst);
