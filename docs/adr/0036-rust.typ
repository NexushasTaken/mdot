#import "../template.typ": adr

#adr(number: 36, title: [The implementation language is Rust], status: [Accepted], date: [2026-10-25])[
= Context
ADR 0002 chose C++20 with CMake, sol2, `tl::expected` and Catch2, and ADR 0025 replaced vcpkg with
Conan. By `cadbba9` the C++ code had `plan_link`, `apply_link`, a basic Lua loader, `classify` and
`generic_decide`, all with tests. The author finds C++ too hard to maintain.

To see what the code looks like in another language, the whole C++ codebase was ported 1:1 to
Rust (branch `rust-rewrite`). All tests were ported and pass, and `mdot plan` gives the same output
and exit code as the C++ build.

= Options
- *Stay with C++.* Rejected by the author: too hard to maintain.
- *Rust.* Chosen.

= Decision
From the author:
- mdot is written in *Rust*. This supersedes ADR 0002 and the dependency-manager part of ADR 0025.
- The starting point is the 1:1 port of the C++ as of `cadbba9`.

Accepted additions:
- *Libraries in use:* `mlua` (Lua 5.4, vendored, so users need no system Lua), `clap` (derive) for
  the CLI, `dirs` for home and XDG directories (replaces platformfolders), `Result` with mdot's own
  error types (replaces `tl::expected`), and `cargo test` (replaces Catch2). Build and dependencies
  are Cargo (replaces CMake and Conan).
- *A library is added only when code needs it* (carried over from ADR 0025). ADR 0025's rule that
  every library comes from Conan Center is dropped.

= Consequences
- ADR 0002 and ADR 0025 are kept unchanged as history. Read their language, build and dependency
  choices as replaced by this ADR. ADR 0025's choice of libcurl and OpenSSL for `net.download` no
  longer applies; see Open.
- Other records that mention C++ or sol2 in passing (ADR 0001, 0003, 0013, 0035, `research.typ`,
  the lessons in `learn/`) are kept as written. They describe what was true at the time.
- ADR 0013's sandbox is language-independent. Its mechanism in mlua is decided while implementing
  it.

= Open
- *Logging:* what replaces spdlog/fmt.
- *State files:* which JSON library replaces nlohmann-json.
- *Structural editing:* how tree-sitter and its grammars are used from Rust.
- *`net.download`:* which HTTP client and hash library replace libcurl and OpenSSL. Not needed in
  Phase 1 (ADR 0024).
]
