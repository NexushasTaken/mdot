#pragma once
#include "error.hpp"
#include "link.hpp"
#include "tl/expected.hpp"

namespace mdot {

tl::expected<LinkPlan, LinkError> apply_link(std::filesystem::path src,
                                             std::filesystem::path dst);

}
