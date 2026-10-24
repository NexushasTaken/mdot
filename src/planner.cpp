#include "planner.hpp"
#include <cassert>
#include <filesystem>
#include <map>
#include <vector>

namespace mdot {

namespace planner {

bool link_match(const Link &link_left, const Link &link_right) {
  assert(link_left.target.is_absolute());
  assert(link_left.dst.is_absolute());
  assert(link_right.target.is_absolute());
  assert(link_right.dst.is_absolute());
  return link_left.target == link_right.target &&
         link_left.dst == link_right.dst;
}

bool LinkLive::match(const LinkDesired *d) const {
  if (d == nullptr) {
    return false;
  }
  return link_match(this->m_link, d->m_link);
}
bool LinkLive::match(const LinkRecord *r) const {
  if (r == nullptr) {
    return false;
  }
  return link_match(this->m_link, r->m_link);
}
bool LinkDesired::match(const LinkRecord *r) const {
  if (r == nullptr) {
    return false;
  }
  return link_match(this->m_link, r->m_link);
}

// clang-format off
// explanation of classify, to properly use it.
// Classify the 3 states(desire, record, live):
//   desire is what the to do with the live
//   record indicates the last recorded changes of mdot.
//   live is what currently on disk
//
//   if desire differs from record, then the spec was changed; or the desire is removed:
//     - this is for what to do with the record according to the desired
//     - if desire is removed, record should be forgotten, and live should not exist.
//   get the status based on the desire and record: this is for what to do with the live according to the desired.
//     Both - means, the spec doesnt need to do anything, the spec and record is also Unchanged.
//     Desired - means, the spec and live is the same, its not recorded.
//       - record should be updated to match the live/spec.
//       - mdot failed after linking
//     Recorded - means, the live and recorded is untouched, but the desired was changed
//       - no external process touched the live
//       - mdot has free to do anything with the live.
//     Absent - means, by the word itself, the live is absent
//       - the mdot can create it on that live.
//     Other - means, is neither Desired or Recorded, the live exist but its doesnt matched to the desired or recorded
//    any changes to live should be recorded.
// clang-format on
ClassifyResult classify(const LinkDesired *desire, const LinkRecord *record,
                        const LinkLive *live) {
  ClassifyResult c;

  // having record and desire to be null is not a valid case.
  assert(!(desire == nullptr && record == nullptr));
  if (desire && record) {
    c.m_desired = desire->match(record) ? DesiredStatus::Unchanged
                                        : DesiredStatus::Changed;
  } else if (record == nullptr) {
    c.m_desired = DesiredStatus::NoRecord;
  } else if (desire == nullptr) {
    c.m_desired = DesiredStatus::Removed;
  }

  if (live == nullptr) {
    c.m_live = LiveStatus::Absent;
  } else {
    bool desired = desire && live->match(desire);
    bool recorded = record && live->match(record);

    if (desired && recorded) {
      c.m_live = LiveStatus::Both;
    } else if (desired) {
      c.m_live = LiveStatus::Desired;
    } else if (recorded) {
      c.m_live = LiveStatus::Recorded;
    } else {
      c.m_live = LiveStatus::Other;
    }
  }

  return c;
}

Action generic_decide(ClassifyResult c) {
  switch (c.m_desired) {
    using enum DesiredStatus;
    using enum LiveStatus;

  case NoRecord:
    if (c.m_live == Absent) {
      return Action::Create;
    }
    if (c.m_live == Desired) {
      return Action::Adopt;
    }
    return Action::Conflict;
  case Unchanged:
  case Changed:
    if (c.m_live == Both) {
      return Action::Noop;
    }
    if (c.m_live == Recorded) {
      return Action::Update;
    }
    return Action::ConflictDrift;
  case Removed:
    if (c.m_live == Recorded) {
      return Action::Delete;
    }
    return Action::Conflict;
  }

  assert(false); // unreachable
  return Action::Noop;
}

void plan(std::vector<LinkDesired> desired_items,
          std::vector<LinkRecord> recorded_items) {
  std::map<std::string, LinkDesired> D;
  std::map<std::string, LinkRecord> R;
}

/*
clang-format off
function plan(kind, desired_items, recorded_items)
  local D = index_by(kind.id, desired_items)   -- error on a duplicate ID: one owner per ID
  local R = index_by(kind.id, recorded_items)

  local steps = {}
  for _, key in ipairs(sorted(union(keys(D), keys(R)))) do  -- sorted: stable output
    local d, r = D[key], R[key]
    local l    = kind.observe(key)                         -- only known IDs are observed
    local c    = classify(d, r, l, kind.match)
    steps[#steps+1] = { key = key, action = kind.decide(c),
                        desired = d, recorded = r, live = l }
  end
  return steps          -- data only: nothing changed. apply() runs the steps later.
end
clang-format on
*/

} // namespace planner
} // namespace mdot
