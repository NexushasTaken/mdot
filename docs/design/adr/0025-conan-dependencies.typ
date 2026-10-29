#import "../template.typ": adr

#adr(number: 25, title: [Dependencies come from Conan, with libcurl and OpenSSL for downloads], status: [Superseded by 0036], date: [2026-10-11])[
= Context
ADR 0002 chose vcpkg (manifest mode) for C++ dependencies and listed Conan as superseded, without
recording why. The author does not want vcpkg and prefers Conan. No `CMakeLists.txt` or build
files exist yet, so nothing has to be migrated.

`net.download` (ADR 0024) also needs an HTTP client and a hash library, which the stack did not
list. Its hashing is incremental, done on bytes as they arrive, so the bytes must be in-process.

= Options
- vcpkg (ADR 0002). Already recorded, but not wanted.
- CMake `FetchContent` only. No package manager, but every dependency builds from source on every
  fresh checkout.
- Conan Center for every library, with a source build as the fallback for any it lacks. Chosen.
- For HTTP: libcurl, or shelling out to `curl` as is done for `git`. Shelling out would force a second
  pass over the file to hash it. libcurl chosen.
- For hashing: OpenSSL (its EVP interface takes an algorithm by name, which fits
  `hash = "<algo>:<hex>"`). Chosen.

= Decision
- C++ dependencies are declared and fetched with *Conan*. This supersedes the dependency-manager part
  of ADR 0002. The rest of ADR 0002 (C++20, CMake, sol2, `tl::expected`, Catch2, and the added
  libraries) stands.
- *Rule: every library comes from Conan Center.* If a library is not in Conan Center, the default is
  to download or clone its source and build it together with the project. The exact mechanism
  (git submodule, copied sources or `FetchContent`) is decided when the first such library is needed.
  Tree-sitter grammars already follow this path (ADR 0002).
- `net.download` uses *libcurl* for HTTP and *OpenSSL* for hashing. The write callback feeds each
  chunk to both the temporary file and the digest.
- Each is added to the build only when the code that needs it is written, not before. `net.download`
  is not in Phase 1 (ADR 0024), so neither is required for Phase 1.

= Consequences
- Amends ADR 0002: read "vcpkg (manifest mode)" there as Conan. ADR 0002 is kept unchanged as
  history.
- Conan adds its own files (`conanfile.txt` or `conanfile.py`) and the CMake integration it
  generates. Details are decided when the skeleton is written.
- Which libraries are actually in Conan Center is not checked now. The rule above decides each case
  when it comes up during implementation.
- The libcurl TLS backend is configurable. It is expected to be OpenSSL so the project has a single
  TLS and hash library, but this must be checked when it is added.
- Closes the library question left open in ADR 0024. Which algorithms beyond sha256 are supported
  is still open.
]
