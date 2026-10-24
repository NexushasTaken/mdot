#pragma once
#include <filesystem>
#include <vector>

namespace mdot {

namespace planner {

enum struct DesiredStatus {
  Unchanged,
  Changed,
  NoRecord,
  Removed,
};

enum struct LiveStatus {
  Both,
  Desired,
  Recorded,
  Absent,
  Other,
};

enum struct Action {
  Conflict,
  ConflictDrift,
  Create,
  Adopt,
  Noop,
  Update,
  Delete,
};

struct ClassifyResult {
  LiveStatus m_live;
  DesiredStatus m_desired;
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

struct Step {
  std::string id;
  Action action;
  LinkDesired desired;
  LinkRecord recorded;
  LinkLive live;
};

ClassifyResult classify(const LinkDesired *desire, const LinkRecord *record,
                        const LinkLive *live);
Action generic_decide(ClassifyResult c);
void plan(std::vector<LinkDesired> desired_items,
          std::vector<LinkRecord> recorded_items);

} // namespace planner
} // namespace mdot
