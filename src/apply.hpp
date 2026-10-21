#pragma once
#include "error.hpp"
#include "link.hpp"
#include "tl/expected.hpp"

tl::expected<LinkPlan, Error> apply_link(std::filesystem::path src,
                                         std::filesystem::path dst);
