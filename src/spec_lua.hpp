#pragma once

#include "spec.hpp"
#include <filesystem>
#include <tl/expected.hpp>

tl::expected<Spec, std::string>
parse_spec(const std::string &name, const std::string &spec_code);
