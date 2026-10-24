#include "spec_lua.hpp"
#include "error.hpp"
#include "spec.hpp"
#include <format>
#include <sol/state.hpp>
#include <string>
#include <tl/expected.hpp>

namespace mdot {

static tl::expected<void, std::string> state_setup(sol::state &state) {
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

tl::expected<LinkClause, ClauseError> static link_clause_from_table(
    std::size_t id, sol::table raw_clause) {
  auto src = raw_clause.get_or<std::optional<std::string>>("src", std::nullopt);
  auto dst = raw_clause.get_or<std::optional<std::string>>("dst", std::nullopt);
  if (!src) {
    return ClauseError::make_error(id, "`src` is required");
  }
  if (!dst) {
    return ClauseError::make_error(id, "`dst` is required");
  }

  LinkClause link = {
      .m_src = *src,
      .m_dst = *dst,
  };

  return link;
}

tl::expected<Spec, std::string> parse_spec(const std::string &name,
                                           const std::string &spec_code) {
  Spec spec;

  sol::state state;
  auto setup_result = state_setup(state);
  if (!setup_result) {
    return tl::make_unexpected(std::format("{}", setup_result.error()));
  }

  auto spec_result = state.safe_script(spec_code, sol::script_pass_on_error);
  if (!spec_result.valid()) {
    sol::error error = spec_result;
    return tl::make_unexpected(std::format("{}", error.what()));
  }

  auto spec_optional = spec_result.get<std::optional<sol::table>>();

  if (!spec_optional) {
    return tl::make_unexpected(
        std::format("{}: spec must return a table, got {}", name,
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
    auto clause_result = link_clause_from_table(i, clause);
    if (!clause_result) {
      return tl::make_unexpected(clause_result.error().string());
    }

    spec.link_clauses.push_back(*clause_result);
  }

  return spec;
}

} // namespace mdot
