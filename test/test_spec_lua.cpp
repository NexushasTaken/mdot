#include "catch2/catch_test_macros.hpp"
#include "spec_lua.hpp"
#include <catch2/catch_message.hpp>

TEST_CASE("valid empty spec", "[spec_lua][valid_spec]") {
  auto r = mdot::parse_spec("test", R"(
    return spec {}
  )");
  INFO((r ? "" : r.error()));
  REQUIRE(r.has_value());
  REQUIRE(r.value().link_clauses.empty());
}

TEST_CASE("valid spec with one clause", "[spec_lua][valid_spec_one_clause]") {
  auto r = mdot::parse_spec("test", R"(
    return spec {
      file.link("src", "dst"),
    }
  )");
  INFO((r ? "" : r.error()));
  REQUIRE(r.has_value());
  REQUIRE(r.value().link_clauses.size() == 1);
  REQUIRE(r.value().link_clauses[0].m_src == "src");
  REQUIRE(r.value().link_clauses[0].m_dst == "dst");
}

TEST_CASE("valid spec with one bad clause call",
          "[spec_lua][valid_spec_bad_clause_call]") {
  auto r = mdot::parse_spec("test", R"(
    return spec {
      file.link("src"),
    }
  )");
  INFO((r ? "" : r.error()));
  REQUIRE(!r.has_value());
  REQUIRE(r.error() == "entry 1: `dst` is required");

  r = mdot::parse_spec("test", R"(
    return spec {
      file.link(),
    }
  )");
  INFO((r ? "" : r.error()));
  REQUIRE(!r.has_value());
  REQUIRE(r.error() == "entry 1: `src` is required");
}

TEST_CASE("non-table return", "[spec_lua][non_table]") {
  auto r = mdot::parse_spec("test", R"(
    return "non-table"
  )");
  INFO((r ? "" : r.error()));
  REQUIRE(!r.has_value());
  REQUIRE(r.error() == "test: spec must return a table, got string");
}

TEST_CASE("not clause", "[spec_lua][not_clause]") {
  auto r = mdot::parse_spec("test", R"(
    return spec {
      "not-clause"
    }
  )");
  INFO((r ? "" : r.error()));
  REQUIRE(!r.has_value());
  REQUIRE(r.error() == "entry 1: is not a valid clause call");
}
