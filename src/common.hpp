#pragma once
#include "tl/expected.hpp"
#include <filesystem>

std::filesystem::path clean_path(const std::filesystem::path &path);

tl::expected<std::filesystem::path, std::error_code>
normalize_path(const std::filesystem::path &path);
