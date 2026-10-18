#include "link.hpp"
#include <cassert>
#include <filesystem>
#include <system_error>
#include <tl/expected.hpp>

namespace fs = std::filesystem;

static tl::unexpected<Error> make_error(const fs::path &path,
                                        std::error_code ec) {
  return tl::make_unexpected(Error{path, ec.message()});
}
static tl::unexpected<Error> make_error(const fs::path &path,
                                        std::string message) {
  return tl::make_unexpected(Error{path, message});
}

static fs::path clean_path(const fs::path &path) {
  if (!path.has_filename()) {
    return path.parent_path();
  }
  return path;
}

static tl::expected<fs::path, std::error_code>
normalize_path(const fs::path &path) {
  std::error_code ec;
  fs::path new_path = path.lexically_normal();
  if (path.is_relative()) {
    auto current_path = fs::current_path(ec);
    if (ec) {
      return tl::make_unexpected(ec);
    }

    auto real = (current_path / path).lexically_normal();
    return clean_path(real);
  }
  return clean_path(path.lexically_normal());
}

// FIX: can't handle permissions yet.
tl::expected<PlanOperation, Error> plan_link(fs::path src, fs::path dst) {
  std::error_code ec;

  {
    auto src_real = normalize_path(src);
    if (!src_real) {
      return make_error(src, src_real.error());
    }
    src = src_real.value();

    auto dst_real = normalize_path(dst);
    if (!dst_real) {
      return make_error(dst, dst_real.error());
    }
    dst = dst_real.value();
  }

  if (!fs::exists(src, ec)) {
    return make_error(src, "No such file or directory");
  }

  if (ec) {
    return make_error(src, ec);
  }

  {
    fs::path root_path = dst.root_path();
    fs::path path;

    for (auto segment : dst) {
      path /= segment;
      if (dst == path) {
        break;
      }

      // TODO: while path < dst - if the ancestor is a dangling link, allow the
      // user to specify, if that should be an error or warning.
      auto path_st = fs::status(path, ec);
      if (path_st.type() == fs::file_type::not_found) {
        break;
      }

      if (ec) {
        return make_error(path, ec);
      }

      if (path_st.type() != fs::file_type::directory) {
        return PlanOperation::Conflict;
      }
    }
  }

  auto dst_st = fs::symlink_status(dst, ec);

  if (dst_st.type() == fs::file_type::not_found) {
    return PlanOperation::Create;
  }

  if (dst_st.type() != fs::file_type::not_found &&
      dst_st.type() != fs::file_type::symlink) {
    return PlanOperation::Conflict;
  }

  if (ec) {
    return make_error(dst, ec);
  }

  auto link_target = clean_path(
      (dst.parent_path() / fs::read_symlink(dst, ec)).lexically_normal());

  if (ec) {
    return make_error(dst, ec);
  }

  if (link_target == src) {
    return PlanOperation::Noop;
  } else {
    return PlanOperation::Conflict;
  }
}
