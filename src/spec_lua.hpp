#pragma once

#include "spec.hpp"
#include <filesystem>
#include <tl/expected.hpp>

tl::expected<Spec, std::string> parse_spec(std::filesystem::path spec_path);
