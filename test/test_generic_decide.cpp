#include "catch2/catch_test_macros.hpp"
#include "catch2/generators/catch_generators.hpp"
#include "planner.hpp"
#include <catch2/catch_message.hpp>

namespace plan = mdot::planner;

TEST_CASE("generic decide", "[generic_decide]") {
  using enum plan::DesiredStatus;
  using enum plan::LiveStatus;
  using enum plan::Action;

  auto [desired, live, expected] =
      GENERATE(table<plan::DesiredStatus, plan::LiveStatus, plan::Action>({
          // clang-format off
          {NoRecord , Absent  , Create}       ,
          {NoRecord , Desired , Adopt}        ,
          {NoRecord , Other   , Conflict}     ,
          {NoRecord , Both    , Conflict}     ,
          {NoRecord , Recorded, Conflict}     ,

          {Changed  , Both    , Noop}         ,
          {Changed  , Recorded, Update}       ,
          {Changed  , Absent  , ConflictDrift},
          {Changed  , Other   , ConflictDrift},
          {Changed  , Desired , ConflictDrift},

          {Unchanged, Both    , Noop}         ,
          {Unchanged, Recorded, Update}       ,
          {Unchanged, Absent  , ConflictDrift},
          {Unchanged, Other   , ConflictDrift},
          {Unchanged, Desired , ConflictDrift},

          {Removed  , Recorded, Delete}       ,
          {Removed  , Both    , Conflict}     ,
          {Removed  , Absent  , Conflict}     ,
          {Removed  , Other   , Conflict}     ,
          {Removed  , Desired , Conflict}     ,
          // clang-format on
      }));
  CAPTURE(desired, live);
  REQUIRE(plan::generic_decide({.m_live = live, .m_desired = desired}) ==
          expected);
}
