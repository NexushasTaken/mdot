#include "catch2/catch_test_macros.hpp"
#include "planner.hpp"
#include <catch2/catch_message.hpp>

namespace plan = mdot::planner;
namespace fs = std::filesystem;

constexpr std::string DST = "/config"; // acts as an ID
constexpr std::string A = "/specs/config";
constexpr std::string B = "/specs/.config";
constexpr std::string C = "/specs/conf";

TEST_CASE("all state are the same", "[classify][same]") {
  plan::Link link = {
      .target = A,
      .dst = DST,
  };
  plan::LinkDesired d = {.m_link = link};
  plan::LinkRecord r = {.m_link = link};
  plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(&d, &r, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Both);
  REQUIRE(res.m_desired == plan::DesiredStatus::Unchanged);
}

TEST_CASE("new spec, no record/live", "[classify][new-spec-no-record-live]") {
  fs::path target = A;
  plan::Link link = {
      .target = target,
      .dst = DST,
  };
  plan::LinkDesired d = {.m_link = link};
  // plan::LinkRecord r = {.m_link = link};
  // plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(&d, nullptr, nullptr);
  REQUIRE(res.m_live == plan::LiveStatus::Absent);
  REQUIRE(res.m_desired == plan::DesiredStatus::NoRecord);
}

TEST_CASE("update live and record", "[classify][update]") {
  plan::Link link = {
      .target = A,
      .dst = DST,
  };
  plan::LinkDesired d = {.m_link = {
                             .target = B,
                             .dst = DST,
                         }};
  plan::LinkRecord r = {.m_link = link};
  plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(&d, &r, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Recorded);
  REQUIRE(res.m_desired == plan::DesiredStatus::Changed);
}

TEST_CASE("possible conflict", "[classify][conflict]") {
  fs::path target = A;
  plan::Link link = {
      .target = target,
      .dst = DST,
  };
  plan::LinkDesired d = {.m_link = link};
  plan::LinkRecord r = {.m_link = link};
  plan::LinkLive l = {.m_link = {
                          .target = B,
                          .dst = DST,
                      }};

  auto res = plan::classify(&d, &r, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Other);
  REQUIRE(res.m_desired == plan::DesiredStatus::Unchanged);
}

TEST_CASE("record needs to be updated", "[classify][record-update]") {
  fs::path target = A;
  plan::Link link = {
      .target = target,
      .dst = DST,
  };
  plan::LinkDesired d = {.m_link = link};
  plan::LinkRecord r = {.m_link = {
                            .target = B,
                            .dst = DST,
                        }};
  plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(&d, &r, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Desired);
  REQUIRE(res.m_desired == plan::DesiredStatus::Changed);
}

TEST_CASE("record needs to be set", "[classify][record-set]") {
  fs::path target = A;
  plan::Link link = {
      .target = target,
      .dst = DST,
  };
  plan::LinkDesired d = {.m_link = link};
  // plan::LinkRecord r = {.m_link = link};
  plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(&d, nullptr, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Desired);
  REQUIRE(res.m_desired == plan::DesiredStatus::NoRecord);
}

TEST_CASE("no record but live differs from desired",
          "[classify][no-record-live-differ-desire]") {
  plan::LinkDesired d = {.m_link = {
                             .target = A,
                             .dst = "/config",
                         }};
  // plan::LinkRecord r = {.m_link = link};
  plan::LinkLive l = {.m_link = {
                          .target = B,
                          .dst = "/config",
                      }};

  auto res = plan::classify(&d, nullptr, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Other);
  REQUIRE(res.m_desired == plan::DesiredStatus::NoRecord);
}

TEST_CASE("removed spec", "[classify][removed-spec]") {
  fs::path target = A;
  plan::Link link = {
      .target = target,
      .dst = DST,
  };
  // plan::LinkDesired d = {.m_link = link};
  plan::LinkRecord r = {.m_link = link};
  plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(nullptr, &r, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Recorded);
  REQUIRE(res.m_desired == plan::DesiredStatus::Removed);
}

TEST_CASE("no desired and live", "[classify][no-record-live]") {
  fs::path target = A;
  plan::Link link = {
      .target = target,
      .dst = DST,
  };
  // plan::LinkDesired d = {.m_link = link};
  plan::LinkRecord r = {.m_link = link};
  // plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(nullptr, &r, nullptr);
  REQUIRE(res.m_live == plan::LiveStatus::Absent);
  REQUIRE(res.m_desired == plan::DesiredStatus::Removed);
}

TEST_CASE("no desire, but live differs from record",
          "[classify][no-desire-live-differ-record]") {
  // plan::LinkDesired d = {.m_link = link};
  plan::LinkRecord r = {.m_link = {
                            .target = A,
                            .dst = DST,
                        }};
  plan::LinkLive l = {.m_link = {
                          .target = B,
                          .dst = DST,
                      }};

  auto res = plan::classify(nullptr, &r, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Other);
  REQUIRE(res.m_desired == plan::DesiredStatus::Removed);
}

TEST_CASE("unchanged desire, but live is absent",
          "[classify][unchanged-desire-live-absent]") {
  plan::Link link = {
      .target = A,
      .dst = DST,
  };
  plan::LinkDesired d = {.m_link = link};
  plan::LinkRecord r = {.m_link = link};
  // plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(&d, &r, nullptr);
  REQUIRE(res.m_live == plan::LiveStatus::Absent);
  REQUIRE(res.m_desired == plan::DesiredStatus::Unchanged);
}

TEST_CASE("desire differs from record, but live is absent",
          "[classify][desire-differ-record-live-absent]") {
  plan::LinkDesired d = {.m_link = {
                             .target = A,
                             .dst = DST,
                         }};
  plan::LinkRecord r = {.m_link = {
                            .target = B,
                            .dst = DST,
                        }};
  // plan::LinkLive l = {.m_link = link};

  auto res = plan::classify(&d, &r, nullptr);
  REQUIRE(res.m_live == plan::LiveStatus::Absent);
  REQUIRE(res.m_desired == plan::DesiredStatus::Changed);
}

TEST_CASE("desire, record and live differs",
          "[classify][desire-record-live-differs]") {
  plan::LinkDesired d = {.m_link = {
                             .target = A,
                             .dst = DST,
                         }};
  plan::LinkRecord r = {.m_link = {
                            .target = B,
                            .dst = DST,
                        }};
  plan::LinkLive l = {.m_link = {
                          .target = C,
                          .dst = DST,
                      }};

  auto res = plan::classify(&d, &r, &l);
  REQUIRE(res.m_live == plan::LiveStatus::Other);
  REQUIRE(res.m_desired == plan::DesiredStatus::Changed);
}
