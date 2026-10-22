#include "CLI/CLI.hpp"
#include "apply.hpp"
#include "common.hpp"
#include "link.hpp"
#include "spdlog/sinks/stdout_color_sinks.h"
#include "spdlog/spdlog.h"
#include "tl/expected.hpp"
#include <cstdlib>
#include <filesystem>
#include <lua.h>
#include <memory>
#include <optional>
#include <sol/error.hpp>
#include <sol/forward.hpp>
#include <sol/load_result.hpp>
#include <sol/protected_function_result.hpp>
#include <sol/state.hpp>
#include <sol/state_handling.hpp>
#include <sol/types.hpp>
#include <spdlog/logger.h>
#include <tl/expected.hpp>

namespace fs = std::filesystem;

struct Core {
  std::shared_ptr<spdlog::logger> errlog;
  // options
  bool planing = false;
};

void link_plan_describe(const Core &core, const LinkPlan &plan) {
  switch (plan.m_operation) {
  case PlanOperation::Create:
    if (core.planing) {
      spdlog::info("would linked: {} -> {}", plan.m_src.string(),
                   plan.m_dst.string());
    } else {
      spdlog::info("linked: {} -> {}", plan.m_src.string(),
                   plan.m_dst.string());
    }
    break;
  case PlanOperation::Noop:
    spdlog::info("already linked");
    break;
  case PlanOperation::Conflict:
    core.errlog->error("{}: {}", plan.m_src.string(), plan.m_message);
    break;
  }
}

struct Spec {
  std::vector<LinkClause> link_clauses;
};

tl::expected<void, std::string> state_setup(sol::state &state) {
  state.open_libraries(sol::lib::base, sol::lib::string, sol::lib::table,
                       sol::lib::math, sol::lib::package);

  sol::protected_function_result link_function_result = state.safe_script(R"(
    file = {}
    function spec(clauses)
      return clauses
    end
    function file.link(src, dst)
      return { src = src, dst = dst }
    end
    )");
  if (!link_function_result.valid()) {
    sol::error error = link_function_result;
    return tl::make_unexpected(error.what());
  }

  return {};
}

tl::expected<Spec, std::string> parse_spec(fs::path spec_path) {
  Spec spec;

  sol::state state;
  state_setup(state);

  auto spec_result =
      state.safe_script_file(spec_path, sol::script_pass_on_error);
  if (!spec_result.valid()) {
    sol::error error = spec_result;
    return tl::make_unexpected(std::format("{}", error.what()));
  }

  auto spec_optional = spec_result.get<std::optional<sol::table>>();

  if (!spec_optional) {
    return tl::make_unexpected(
        std::format("{} must return a table, got {}", spec_path.string(),
                    sol::type_name(state, spec_result.get_type())));
  }

  sol::table raw_spec = *spec_optional;
  for (std::size_t i = 1; i <= raw_spec.size(); i++) {
    auto spec_element = raw_spec.get<std::optional<sol::table>>(i);
    if (!spec_element) {
      return tl::make_unexpected(
          ClauseError::make_error(i, "is not a valid clause call")
              .value()
              .string());
    }

    auto clause = *spec_element;
    auto clause_result = LinkClause::from_table(i, clause);
    if (!clause_result) {
      return tl::make_unexpected(clause_result.error().string());
    }

    spec.link_clauses.push_back(*clause_result);
  }

  return spec;
}

tl::expected<bool, std::string> process_spec(const Core &core,
                                             const fs::path &spec_path) {
  bool success = true;
  std::error_code ec;

  if (spec_path.is_relative()) {
    return tl::make_unexpected(
        std::format("{}: must be absolute path", spec_path.string()));
  }

  const fs::path spec_file = spec_path / "spec.lua";

  {
    auto spec_path_st = fs::symlink_status(spec_path, ec);
    if (ec) {
      return tl::make_unexpected(
          std::format("{}: {}", spec_path.string(), ec.message()));
    }
    if (spec_path_st.type() != fs::file_type::directory) {
      return tl::make_unexpected(std::format("{}: {}", spec_file.string(),
                                             "is not a valid spec directory"));
    }

    auto spec_st = fs::symlink_status(spec_file, ec);
    if (ec) {
      return tl::make_unexpected(
          std::format("{}: {}", spec_file.string(), ec.message()));
    }

    if (spec_st.type() != fs::file_type::regular) {
      return tl::make_unexpected(std::format("{}: {}", spec_file.string(),
                                             "is not a valid spec file"));
    }
    if (spec_st.type() == fs::file_type::not_found) {
      return tl::make_unexpected(
          std::format("{}: {}", spec_path.string(), "spec file not found"));
    }
  }

  const fs::path previous_path = fs::current_path(ec);
  if (ec) {
    return tl::make_unexpected(
        std::format("{}: {}", spec_path.string(), ec.message()));
  }
  fs::current_path(spec_path, ec);
  if (ec) {
    return tl::make_unexpected(
        std::format("{}: {}", spec_path.string(), ec.message()));
  }

  auto spec_result = parse_spec(spec_file);

  if (!spec_result) {
    return tl::make_unexpected(spec_result.error());
  }

  Spec spec = *spec_result;
  spdlog::info("{}", fs::current_path().string());

  for (auto &clause : spec.link_clauses) {
    auto src_result = resolve_path(clause.m_src);
    if (!src_result) {
      return tl::make_unexpected(
          std::format("{}: {}", clause.m_src, src_result.error()));
    }
    auto dst_result = resolve_path(clause.m_dst);
    if (!dst_result) {
      return tl::make_unexpected(
          std::format("{}: {}", clause.m_dst, dst_result.error()));
    }

    const auto src = *src_result;
    const auto dst = *dst_result;

    tl::expected<LinkPlan, LinkError> link_result;
    if (core.planing) {
      link_result = plan_link(src, dst);
    } else {
      link_result = apply_link(src, dst);
    }

    if (link_result) {
      link_plan_describe(core, *link_result);
    } else {
      return tl::make_unexpected(link_result.error().string());
    }

    if (link_result->is_conflict()) {
      success = false;
    }
  }

  fs::current_path(previous_path, ec);
  if (ec) {
    return tl::make_unexpected(
        std::format("{}: {}", spec_path.string(), ec.message()));
  }

  return success;
}

int main(int argc, char *argv[]) {
  Core core = {.errlog = spdlog::stderr_color_mt("errlog")};

  std::string input_spec_path;

  CLI::App app("dotfile manager", "mdot");
  app.fallthrough();

  // test: "test/test-migration/specs/bash/spec.lua";

  auto plan_subcmd = app.add_subcommand("plan", "Plan the specified spec");
  auto apply_subcmd = app.add_subcommand("apply", "Plan the specified spec");

  for (auto *sub : {plan_subcmd, apply_subcmd}) {
    sub->add_option("spec", input_spec_path, "Target of the spec")->required();
  }
  app.require_subcommand(1);

  CLI11_PARSE(app, argc, argv);

  if (*plan_subcmd) {
    core.planing = true;
  } else if (*apply_subcmd) {
    core.planing = false;
  }

  const auto spec_path_result = resolve_path(input_spec_path);
  if (!spec_path_result) {
    core.errlog->error("{}", spec_path_result.error());
    return EXIT_FAILURE;
  }
  const auto spec_path = *spec_path_result;

  auto result = process_spec(core, spec_path);
  if (!result) {
    core.errlog->error("{}", result.error());
    return EXIT_FAILURE;
  }
  return *result ? EXIT_SUCCESS : EXIT_FAILURE;
}
