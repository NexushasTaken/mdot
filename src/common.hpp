#pragma once
#include "tl/expected.hpp"
#include <filesystem>

std::filesystem::path clean_path(const std::filesystem::path &path);

tl::expected<std::filesystem::path, std::string>
normalize_path(const std::filesystem::path &path);

tl::expected<std::filesystem::path, std::string>
expand_home(const std::filesystem::path &path);

tl::expected<std::filesystem::path, std::string>
resolve_path(const std::filesystem::path &path);
