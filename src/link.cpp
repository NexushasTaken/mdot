#include "link.hpp"
#include "common.hpp"
#include "error.hpp"
#include <cassert>
#include <filesystem>
#include <spdlog/spdlog.h>
#include <system_error>
#include <tl/expected.hpp>

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
tl::expected<LinkPlan, Error> plan_link(const fs::path &src,
                                        const fs::path &dst) {
  std::error_code ec;

  fs::path normalized_dst;
  fs::path normalized_src;

  {
    auto src_real = normalize_path(src);
    if (!src_real) {
      return make_error(normalized_src, src_real.error());
    }
    normalized_src = src_real.value();

    auto dst_real = normalize_path(dst);
    if (!dst_real) {
      return make_error(normalized_dst, dst_real.error());
    }
    normalized_dst = dst_real.value();
  }

  if (!fs::exists(normalized_src, ec)) {
    if (ec) {
      return make_error(normalized_src, ec);
    } else {
      return make_error(normalized_src, "No such file or directory");
    }
  }

  {
    fs::path root_path = normalized_dst.root_path();
    fs::path path;

    for (auto segment : normalized_dst) {
      path /= segment;
      if (normalized_dst == path) {
        break;
      }

      // TODO: while path < normalized_dst - if the ancestor is a dangling link,
      // allow the user to specify, if that should be an error or warning.
      auto path_st = fs::status(path, ec);
      if (path_st.type() == fs::file_type::not_found) {
        break;
      }

      if (ec) {
        return make_error(path, ec);
      }

      if (path_st.type() != fs::file_type::directory) {
        return LinkPlan::make_conflict(path, "Is not a directory");
      }
    }
  }

  auto dst_st = fs::symlink_status(normalized_dst, ec);

  if (dst_st.type() == fs::file_type::not_found) {
    return LinkPlan::make_create(normalized_src, normalized_dst);
  }

  if (ec) {
    return make_error(normalized_dst, ec);
  }

  if (dst_st.type() != fs::file_type::not_found &&
      dst_st.type() != fs::file_type::symlink) {
    return LinkPlan::make_conflict(normalized_dst, "Is not a symlink");
  }

  fs::path dst_target = clean_path(
      (normalized_dst.parent_path() / fs::read_symlink(normalized_dst, ec))
          .lexically_normal());

  if (ec) {
    return make_error(normalized_dst, ec);
  }

  if (dst_target == normalized_src) {
    return LinkPlan::make_noop();
  } else {
    return LinkPlan::make_conflict(normalized_dst,
                                   "Symlinked to different file");
  }
}
