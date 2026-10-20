#include "CLI/CLI.hpp"
#include "apply.hpp"
#include "link.hpp"
#include "spdlog/sinks/stdout_color_sinks.h"
#include "spdlog/spdlog.h"
#include "tl/expected.hpp"
#include <filesystem>
#include <memory>
#include <spdlog/logger.h>
#include <system_error>
#include <tl/expected.hpp>

namespace fs = std::filesystem;

struct Core {
  std::shared_ptr<spdlog::logger> errlog;
  // options
  bool dry_run = false;
};

int plan_describe(const Core &core,
                  const tl::expected<PlanOperation, Error> &result) {
  if (!result) {
    core.errlog->error("{}", result.error().string());
    return 3;
  }

  const PlanOperation &plan = *result;

  switch (plan.m_operation) {
  case PlanOperation::Create:
    if (core.dry_run) {
      spdlog::info("would linked: {} -> {}", plan.m_src.string(),
                   plan.m_dst.string());
    } else {
      spdlog::info("linked: {} -> {}", plan.m_src.string(),
                   plan.m_dst.string());
    }
    return 0;
  case PlanOperation::Noop:
    spdlog::info("already linked");
    return 0;
  case PlanOperation::Conflict:
    core.errlog->error("{}: {}", plan.m_src.string(), plan.m_message);
    return 2;
  }

  return 0;
}

int main(int argc, char *argv[]) {
  Core options = {.errlog = spdlog::stderr_color_mt("errlog")};
  std::string src;
  std::string dst;

  CLI::App app("dotfile manager", "mdot");
  app.fallthrough();
  app.add_flag("--dry-run", options.dry_run, "Dry run");

  auto link = app.add_subcommand("link", "symlink a file");
  link->add_option("src", src, "Target of the link")->required();
  link->add_option("dst", dst, "Destination of the symlink")->required();
  app.require_subcommand(1);

  CLI11_PARSE(app, argc, argv);

  if (options.dry_run) {
    const auto &plan_result = plan_link(src, dst);
    return plan_describe(options, plan_result);
  } else {
    const auto &apply_result = apply_link(src, dst);
    return plan_describe(options, apply_result);
  }

  return 0;
}
