# ADR-0002: Stack — C++20, CMake, vcpkg, sol2, tl::expected, Catch2

- Status: Accepted
- Date: 2026-10-06

## Context
The port plan fixed C++20, CMake, sol2 (Lua), `tl::expected`, Catch2, and vcpkg. An earlier design
session had chosen Conan instead of vcpkg.

## Options
- C++ dependency management: Conan, vcpkg, or CMake FetchContent.

## Decision
Keep the port plan's stack, with **vcpkg** (manifest mode) for C++ dependencies. Additional libraries
introduced by the design: CLI11, spdlog/fmt, nlohmann-json, tree-sitter. Git is accessed by shelling
out to the system `git`, not libgit2.

## Consequences
- The Conan choice from the earlier session is superseded.
- Tree-sitter grammars may not all be in vcpkg; they will be vendored as needed.
- Shelling out to `git` keeps the dependency set small but requires `git` at runtime.
