#include "link.hpp"
#include "common.hpp"
#include "error.hpp"
#include <cassert>
#include <filesystem>
#include <spdlog/spdlog.h>
#include <system_error>
#include <tl/expected.hpp>

namespace mdot {

namespace fs = std::filesystem;

LinkPlan LinkPlan::make_create(std::filesystem::path src,
                               std::filesystem::path dst) {
  return {
      .m_src = src,
      .m_dst = dst,
      .m_operation = PlanOperation::Create,
  };
}

LinkPlan LinkPlan::make_conflict(std::filesystem::path src,
                                 std::string message) {
  return {
      .m_src = src,
      .m_message = message,
      .m_operation = PlanOperation::Conflict,
  };
}
LinkPlan LinkPlan::make_noop() {
  return {
      .m_operation = PlanOperation::Noop,
  };
}

// FIX: can't handle permissions yet.
tl::expected<LinkPlan, LinkError> plan_link(const fs::path &src,
                                            const fs::path &dst) {
  std::error_code ec;

  if (src.is_relative()) {
    return LinkError::make_error(src, "must be absolute path");
  }
  if (dst.is_relative()) {
    return LinkError::make_error(dst, "must be absolute path");
  }

  if (!fs::exists(src, ec)) {
    if (ec) {
      return LinkError::make_error(src, ec);
    } else {
      return LinkError::make_error(src, "No such file or directory");
    }
  }

  {
    fs::path root_path = dst.root_path();
    fs::path path;

    for (auto segment : dst) {
      path /= segment;
      if (dst == path) {
        break;
      }

      // TODO: while path < normalized_dst - if the ancestor is a dangling
      // link, allow the user to specify, if that should be an error or
      // warning.
      auto path_st = fs::status(path, ec);
      if (path_st.type() == fs::file_type::not_found) {
        break;
      }

      if (ec) {
        return LinkError::make_error(path, ec);
      }

      if (path_st.type() != fs::file_type::directory) {
        return LinkPlan::make_conflict(path, "Is not a directory");
      }
    }
  }

  auto dst_st = fs::symlink_status(dst, ec);

  if (dst_st.type() == fs::file_type::not_found) {
    return LinkPlan::make_create(src, dst);
  }

  if (ec) {
    return LinkError::make_error(dst, ec);
  }

  if (dst_st.type() != fs::file_type::not_found &&
      dst_st.type() != fs::file_type::symlink) {
    return LinkPlan::make_conflict(dst, "Is not a symlink");
  }

  fs::path dst_target = mdot::clean_path(
      (dst.parent_path() / fs::read_symlink(dst, ec)).lexically_normal());

  if (ec) {
    return LinkError::make_error(dst, ec);
  }

  if (dst_target == src) {
    return LinkPlan::make_noop();
  } else {
    return LinkPlan::make_conflict(dst, "Symlinked to different file");
  }
}

}
