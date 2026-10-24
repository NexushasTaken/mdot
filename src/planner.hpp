#pragma once
#include <filesystem>

namespace mdot {

namespace planner {

enum struct SpecChanged {
  Unchanged,
  Changed,
  New,
  Removed,
};

enum struct LiveStatus {
  Both,
  Desired,
  Recorded,
  Absent,
  Other,
};

struct ClassifyResult {
  LiveStatus m_live;
  SpecChanged m_spec_changed;
};

struct Link {
  std::filesystem::path target;
  std::filesystem::path dst;
};

struct LinkRecord {
  Link m_link;
};

struct LinkDesired {
  Link m_link;
  bool match(const LinkRecord *d) const;
};
struct LinkLive {
  Link m_link;
  bool match(const LinkDesired *d) const;
  bool match(const LinkRecord *d) const;
};

ClassifyResult classify(const LinkDesired *desire, const LinkRecord *record,
                        const LinkLive *live);

} // namespace planner
} // namespace mdot
