# Comtrya: Rust → C++ Port Plan

Source: https://github.com/NexushasTaken/comtrya
Analyzed size: ~12,000 lines Rust across 3 crates (`lib`, `app`, `jsonschemagen`)

## 1. What Comtrya actually is

A CLI provisioning tool (think "Ansible for a single machine"). You write YAML
manifests describing desired state — install packages, copy files, clone repos,
add users — and Comtrya plans a dependency-ordered execution graph and runs it.

Core pipeline, confirmed from source:

```
YAML manifests on disk
   -> Manifest { actions: Vec<Actions>, depends, labels, where }   (serde deserialize)
   -> DAG built from `depends` fields                              (petgraph)
   -> topological walk (DfsPostOrder)
   -> for each Manifest: for each Action: action.plan() -> Vec<Step>
   -> for each Step: initializers gate execution -> atom.execute() -> finalizers gate continuation
```

Two distinct abstraction layers, and this distinction matters for the port:

- **Action** (`lib/src/actions/`) — declarative, one per YAML action type
  (`file.copy`, `package.install`, `user.add`, ...). `Action::plan()` takes a
  `Manifest` + `Contexts` and returns `Vec<Step>`. Pure planning, no side effects.
- **Atom** (`lib/src/atoms/`) — the actual side-effecting unit of work
  (`Atom::plan()` checks if it needs to run, `Atom::execute()` does it).
  Same name overload as the YAML "action" concept is confusing but the code
  is consistent about it.

This two-layer separation (declarative plan vs. imperative execution) is the
single most important thing to preserve. It's also genuinely good architecture
that translates cleanly to C++ virtual interfaces — this is not a case where
we need to fight the design.

## 2. Dependency reality check

I greped actual usage extents rather than going by Cargo.toml alone, since
having a dependency listed doesn't mean it's load-bearing everywhere:

| Rust dependency | Purpose | Files touched | C++ replacement difficulty |
|---|---|---|---|
| `serde` + `serde_yaml_ng` + `toml` + `schemars` | Parse manifests, generate JSON schema | ~all action structs | **DECIDED: `reflect-cpp`** (https://github.com/getml/reflect-cpp) for the struct definitions/validation side — it's explicitly designed as a serde-equivalent for C++20 (reflection-based, no macros). Its role shrinks once manifests become Lua tables (see Section 3b): reflect-cpp is no longer the YAML-parsing path, since there's no YAML left to parse. It's still useful for (a) the `Manifest`/action struct *definitions* and validation rules, and (b) `jsonschemagen`-equivalent JSON schema generation if that's kept. The manifest-table-to-struct walk itself goes through sol2 directly (Lua table → C++ struct), with reflect-cpp potentially used as the typed target of that conversion rather than the parser of raw text. |
| `rhai` | Evaluate `where:` condition strings | 3 files only | **DECIDED: Lua via sol2.** See Section 3a/3b — superseded by the broader Lua-manifest decision; conditions are now just Lua expressions evaluated in the same engine that loaded the manifest. |
| `tera` | Render `{{ expr }}` template strings inside YAML values (e.g. `{{ read_file_contents(path="...") }}`) | 7 files | **DECIDED: dropped.** See Section 3b. Once manifest values are native Lua expressions/function calls rather than strings-containing-a-second-template-language, Tera's job is redundant. `read_file_contents` and other Tera custom functions become plain Lua functions registered on the manifest-loading sol2 state. |
| `tealr` + `mlua` (Lua) | Plugin system — manifests can call out to Lua scripts | 5 files | **DECIDED: sol2.** Being specific per your correction: sol2 (https://github.com/ThePhD/sol2) is the C++ binding library, used as the one Lua engine for manifests, conditions, and the plugin system. |
| `gix` (pure-Rust git) | `git.clone` action, git-based manifest repos | 5 files | **Low.** No equivalent pure-C++ git implementation that's worth using. Replace with: shelling out to system `git`, or linking `libgit2` (battle-tested C library, used by GitHub itself). Recommend libgit2. |
| `reqwest` + `octocrab` + `tokio` | HTTP downloads, GitHub releases API | 2 files use async at all | **Low.** Barely used. `libcurl` or `cpr` (C++ wrapper over libcurl) covers HTTP. No real async architecture to preserve — can go fully synchronous. |
| `petgraph` | DAG construction + topological walk for manifest dependency order | manifests loading, apply command | **Low.** Either link Boost.Graph, or — given the actual usage is "build a DAG, walk it in dependency order" — hand-roll ~80 lines of topological sort. I'd hand-roll it; pulling in Boost.Graph for one algorithm is heavier than the problem. |
| `anyhow` | Error handling | everywhere | **N/A — decided.** Using `tl::expected<T, E>`. See Section 4.1. |
| `clap` | CLI argument parsing | `app/` only | **Low.** `CLI11` or `cxxopts` are direct equivalents. |
| `tracing` | Structured logging | everywhere | **Low.** `spdlog` is the standard choice. |
| OS-specific syscalls (`uzers`, `file-owner`, chown/chmod) | user/group/file ownership actions | `actions/user/`, `actions/group/`, `atoms/file/chown.rs` | **Low.** Direct POSIX syscalls (`getpwnam`, `chown`, `chmod`) — Rust was wrapping the same syscalls C++ calls natively, so this is actually *easier* in C++. |
| `age` (encryption) | encrypted file support on `file.copy` | 1 file (`atoms/file/decrypt.rs`) | **N/A — decided.** Removed from the port entirely, not replaced. See Section 4.5. |

**Net assessment after reading the actual code:** the dependency list looked
scary in Cargo.toml, but usage is concentrated. Rhai: 3 files. Lua: 5 files.
Git: 5 files. Async: 2 files. The bulk of the 12K lines — the 30 action/atom
implementations, the package manager providers (13 of them), the user/group
providers (4 OS variants each) — are plain, portable logic: shell out to a
command, check a condition, copy a file, format a string. That part is a
mechanical, if tedious, translation.

## 3. Proposed C++ architecture

Mirror the existing module boundaries — they're good:

```
comtrya-cpp/
  CMakeLists.txt
  lib/                          (maps to Rust `lib` crate)
    include/comtrya/
      action.hpp                 // Action interface
      atom.hpp                   // Atom interface
      manifest.hpp
      step.hpp
      contexts.hpp
    src/
      actions/
        command/run.cpp
        directory/{copy,create,remove}.cpp
        file/{copy,chown,download,link,remove,unarchive}.cpp
        git/clone.cpp
        group/{add.cpp, providers/{linux,macos,freebsd,none}.cpp}
        user/{add.cpp, add_group.cpp, providers/{...}.cpp}
        package/{install.cpp, repository.cpp, providers/{aptitude,dnf,homebrew,...}.cpp}  (13 providers)
        macos/default.cpp
        binary/github.cpp
        plugin/plugin.cpp
      atoms/
        command/exec.cpp
        directory/{create,remove}.cpp
        file/{chmod,chown,contents,copy,create,link,remove,unarchive}.cpp
        git/clone.cpp
        http/download.cpp
        plugin/{exec,globals,plugin_spec}.cpp
      manifests/
        load.cpp                 // reads .lua manifest files, executes via
                                  // sol2, walks returned table into Manifest
        providers/{local,git}.cpp
      contexts/
        {env,os,privilege,user,variables}.cpp
        variable_include/{file,dns}.cpp
      steps/
        initializers/{command_found,env_vars_set,file_exists}.cpp
        finalizers/{env_vars_remove,output_contains}.cpp
      scripting/
        condition_evaluator.cpp  // Lua-based, replaces Rhai — see Section 3a
        lua_engine.cpp           // shared sol2 state setup, used by manifest
                                  // loading, condition_evaluator.cpp, and the
                                  // plugin system
      config/
  app/                           (maps to Rust `app` crate — the CLI binary)
    src/
      main.cpp
      commands/{apply,contexts,gen_completions,plugin,version}.cpp
      config/
  third_party/ or vcpkg.json     // sol2 (Lua), reflect-cpp, libcurl/cpr,
                                  // libgit2, CLI11, spdlog, tl::expected,
                                  // Catch2
  tests/
```

### Key interface translations

**Action trait → abstract class:**
```cpp
// Rust: fn plan(&self, manifest: &Manifest, context: &Contexts) -> Result<Vec<Step>>
class Action {
public:
    virtual ~Action() = default;
    virtual std::string summarize() const { return "not found action summarize"; }
    virtual tl::expected<std::vector<Step>, ActionError>
        plan(const Manifest& manifest, const Contexts& context) const = 0;
};
```

**Atom trait → abstract class:**
```cpp
class Atom {
public:
    virtual ~Atom() = default;
    virtual tl::expected<Outcome, std::string> plan() const = 0;
    virtual tl::expected<void, std::string> execute() = 0;
    virtual std::string output_string() const { return ""; }
    virtual std::string error_message() const { return ""; }
    virtual int status_code() const { return 0; }
    virtual std::string display() const = 0;
};
```

**The `Actions` tagged enum** (currently a hand-written 19-variant Rust enum
with manual `Deref`/`Display` impls dispatching on a `#[serde(tag = "action")]`
string) becomes a **registry pattern**: a `std::unordered_map<std::string,
std::function<std::unique_ptr<Action>(const sol::table&)>>` populated at
startup, keyed by the same action-name strings (`"file.copy"`,
`"package.install"`, etc., including the existing aliases like `"dir.copy"`).
The factory function for each registered action reads its own fields
straight out of the Lua table for that action entry. This is arguably
cleaner than the Rust version's hand-rolled enum and avoids re-deriving
serde's tag-dispatch by hand.

**`ConditionalVariantAction<T>` generic wrapper** (handles `where:` and
`variants:` on every action) becomes a C++ template class wrapping any
`Action`-implementing type — direct translation, templates handle this fine.

## 3a. Condition evaluation via Lua (replaces Rhai)

Confirmed from `lib/src/contexts/mod.rs` and real example manifests:

- `Contexts` is a two-level map: `BTreeMap<String, BTreeMap<String, Value>>`
  — e.g. `contexts["os"]["name"]`, `contexts["user"]["username"]`,
  `contexts["variables"]["fkbr"]`.
- It's pushed into the Rhai scope as **read-only constants**, one Rhai
  variable per top-level prefix (`os`, `user`, `env`, `variables`, ...), each
  holding a nested map/object.
- Real conditions from the repo's own examples and docs:
  - `os.name == "linux"`
  - `os.family == "unix"`
  - `os.distribution == "Ubuntu"`
  - `user.username == "rawkode"`
  - `variables.fkbr == "sxoe" && variables.kuci == "xhpv"`
- `Value` (`lib/src/values/mod.rs`) is a small closed enum: `Null`, `String`,
  `Number` (unsigned/signed/float, compares across all three), `List`.

**C++ design:**

```cpp
// One sol2 (or similar) Lua state, used for BOTH condition eval and plugins.
class ConditionEvaluator {
public:
    explicit ConditionEvaluator(const Contexts& contexts);
    // Returns false on Lua error, logging the error — mirrors the Rust
    // behavior of "error -> treat as false, log it" seen in
    // ConditionalVariantAction::plan.
    bool evaluate(const std::string& condition) const;
private:
    sol::state lua_;
};
```

Build process, run once per `Contexts` (matches Rust's `to_rhai`'s role):

1. Create one Lua global table, `contexts`. This matches the convention
   **already established** in the existing Rust plugin bridge
   (`lib/src/atoms/plugin/globals.rs::add_context`), which exposes values as
   `contexts.os.name`, `contexts.user.username`, etc. — nested under a
   single `contexts` table, not flattened to bare top-level globals.
2. For each top-level prefix in `Contexts` (`os`, `user`, `env`, `variables`,
   ...), create a nested table under `contexts`, populated key by key,
   converting `Value` → Lua value (`String`→string, `Number`→Lua number,
   `List`→1-indexed table, `Null`→`nil`).
3. `evaluate(condition)` wraps the string as `return (<condition>)` and runs
   it via the Lua state, expecting a boolean result.

**Important discrepancy to resolve, not gloss over:** real `where:`
conditions in the existing Rust codebase (Rhai-based) use **bare** top-level
names — `os.name == "linux"`, `user.username == "rawkode"` — not
`contexts.os.name`. The existing Lua plugin bridge uses the `contexts.`
prefix. These two conventions don't match today because they're two
separate systems in the Rust code (Rhai for conditions, Lua for plugins).
Once unified onto one Lua engine, pick one:
  - **Match existing manifests (no `contexts.` prefix in `where:`):** keep
    conditions using bare names (`os.name`) by setting `os`, `user`, etc.
    directly as Lua globals for condition evaluation, while plugins keep
    using the `contexts.` table for their own script bodies. Two slightly
    different global setups sharing one engine — still one dependency, just
    two thin setup functions.
  - **Unify on `contexts.` everywhere:** requires existing manifests'
    `where:` clauses to be rewritten from `os.name == "linux"` to
    `contexts.os.name == "linux"`. Cleaner internally, breaks drop-in
    compatibility with manifests written for the original Rhai-based tool.

I'd lean toward the first option (preserve bare names in `where:`, since
that's a parse-time string the user writes and changing it is a breaking
change to every existing `.yaml` manifest in the wild), but this is your
call — flagging it now so it doesn't get decided by accident later.

**Why this is the right call, not just the easy one:** the plugin system
(`lib/src/atoms/plugin/`, `lib/src/utilities/lua.rs`) already needs a Lua
engine with context values exposed as globals — the existing `globals.rs` is
almost certainly doing the same "expose Contexts as Lua globals" job that
conditions need. One Lua state (via sol2), set up once per run, reused for
both. This removes an entire dependency (Rhai) from the table in Section 2
— down to one scripting engine instead of two.

**Compatibility note worth flagging now:** existing Comtrya YAML manifests
in the wild use Rhai syntax (`&&`, `||`, possibly other Rhai-specific
operators if anyone's gotten creative in a `where:` clause). If preserving
drop-in compatibility with existing manifests matters, the `&&`→`and`,
`||`→`or` string preprocessing step needs to be reasonably thorough — not
a naive find-and-replace, since `&&` could theoretically appear inside a
quoted string value being compared. If it's acceptable for the C++ port to
require minor manifest syntax updates instead (write `and`/`or` directly),
this gets simpler and that risk disappears. Worth deciding once we're
actually at Phase 3 of the build order, not right now.

## 3b. Manifests as Lua tables (replaces YAML/TOML entirely)

**Decided: manifests are authored as Lua scripts returning a table that
mirrors the current YAML structure 1:1**, e.g.:

```lua
-- Current YAML (lib's existing format):
-- actions:
--   - action: file.copy
--     from: dotfiles/gitconfig
--     to: ~/.gitconfig
-- depends: [other-manifest]

-- Becomes:
return {
  actions = {
    { action = "file.copy", from = "dotfiles/gitconfig", to = "~/.gitconfig" },
  },
  depends = { "other-manifest" },
}
```

**YAML/TOML support is dropped entirely** — not kept for migration, not
supported alongside Lua. `.lua` manifest files only. This is a real,
deliberate break from the upstream Rust tool's file format, not an internal
implementation detail — flagging that plainly since it means existing
Comtrya users' `.yaml`/`.toml` manifests will need to be rewritten, not just
recompiled against.

**This decision resolves three things that were previously open or messy:**

1. **Tera is dropped** (see Section 2 table). Template strings like
   `'{{ read_file_contents(path="...") }}'` were working around YAML being
   a static format. Lua isn't static — the same job is just
   `read_file_contents("...")` as a normal function call returning a normal
   string, assigned directly to a table field. No template-string parsing
   pass needed at all.

2. **The `where:` bare-names-vs-`contexts.`-prefix question from Section 3a
   is now answered by construction, not by picking a side.** Since the
   *entire manifest* executes as Lua, `where:` is no longer a separate
   string later handed to a condition evaluator — it's just another field
   in the table, written as a Lua expression in the same scope as
   everything else in that file:
   ```lua
   return {
     actions = {
       { action = "package.install", name = "git", where = (os.name == "linux") },
     },
   }
   ```
   Whatever globals are exposed to the manifest script (`os`, `user`,
   `variables`, ...) are exposed once, the same way, for the whole file —
   manifest structure, `where:` conditions, and any inline logic all read
   them identically. The plugin system's separate `contexts.` table
   convention (Section 3a) can stay scoped to *plugin* scripts specifically,
   since those are a genuinely different execution context (invoked
   separately, not part of manifest loading) — but manifests themselves
   don't need that prefix.

3. **`reflect-cpp`'s role narrows** (see Section 2 table) — it's no longer
   doing text-format parsing (no YAML text to parse), but it can still
   define and validate the *shape* `Manifest`/`Action` structs are expected
   to have once a Lua table is converted into them.

**C++ design implications:**

- Manifest loading (`lib/src/manifests/load.cpp` in Section 3's file tree)
  changes from "read file → render Tera → parse YAML/TOML text → serde into
  `Manifest`" to **"read file → `sol2` execute as Lua chunk → returned
  `sol::table` → walk table into `Manifest` struct."**
- The table-walk step needs hand-written `sol::table` → struct conversion
  per field (sol2 supports this directly: `table.get<std::string>("action")`,
  etc.) — this replaces serde's `#[derive(Deserialize)]` magic. This is
  genuinely more manual than serde was, which is the real cost of this
  decision; reflect-cpp doesn't have a built-in "Lua table" backend the way
  it has JSON/YAML/TOML backends, so the sol2-table-to-struct conversion
  is bespoke code we write, not a reflect-cpp format plugin. Worth
  reconfirming this is acceptable before Phase 1, since it's more code than
  "reflect-cpp parses it for us" would have been.
- One sol2 Lua state per manifest load (or one shared state, scripts run in
  fresh sandboxed environments/tables per file) — needs deciding at
  implementation time: shared state for performance vs. per-file isolation
  for safety (a manifest accidentally setting a global that leaks into the
  next manifest's evaluation). I'd lean toward per-file isolated
  environments (`sol::environment` in sol2) precisely to avoid that leakage
  class of bug, but this is a Phase 1 implementation detail, not a
  structural decision needed right now.
- `depends:`, `labels:`, action lists — all become straightforward table
  walks once the Lua chunk has executed and returned its table.



## 4. Decisions made so far

1. ~~Error handling style~~ **DECIDED: `tl::expected`** (TartanLlama's
   header-only `expected<T,E>`, https://tl.tartanllama.xyz/). Same API shape
   as `std::expected` (it's the library `std::expected` was largely modeled
   on), but works down to C++11, so no C++23 compiler dependency. Means
   every `Result<T, E>`-returning function in the Rust code (which is most
   of them — `Action::plan`, `Atom::plan`/`execute`, manifest loading, etc.)
   maps to a `tl::expected<T, E>` return type. Worth deciding the shape of
   `E` early since it propagates everywhere — a single `ActionError` /
   `std::string` style error, or distinct error types per subsystem. Cheap
   to migrate to real `std::expected` later if/when C++23 is universally
   available, since the API is intentionally near-identical.
2. ~~C++ standard target~~ **DECIDED: C++20.** `tl::expected` removes the
   pull toward C++23, and `reflect-cpp` (decision 7) requires C++20 itself,
   so C++20 is both sufficient and necessary. Nothing else decided so far —
   CMake, sol2, Catch2, libcurl/libgit2 — requires anything newer.
3. ~~Build system~~ **DECIDED: CMake**, as primary build system.
4. ~~Rhai conditions — reuse Lua or write a tiny evaluator?~~ **DECIDED: Lua,
   specifically via sol2** (https://github.com/ThePhD/sol2) as the C++ Lua
   binding library. One sol2-managed Lua engine for manifests, `where:`
   conditions, and the plugin system. See Sections 3a/3b.
5. ~~`age` encryption support~~ **DECIDED: removed.** The `file.copy`
   action's optional `passphrase` field and the whole `Decrypt` atom
   (`lib/src/atoms/file/decrypt.rs`) are dropped from the port — not carried
   forward as a stub, not deferred-with-a-TODO, just not part of the C++
   `file.copy` implementation. This is a real, if narrow, feature
   reduction versus the Rust original: any existing manifest using
   `passphrase:` on `file.copy` (see `examples/file/filecopy.yaml`) will
   need that encrypted-file workflow handled some other way (e.g. decrypt
   out-of-band before Comtrya runs, or shell out to the `age` CLI from a
   `command.run` action instead). Flagging this plainly in case it surfaces
   later as "wait, where did encrypted file support go."
6. ~~Test strategy~~ **DECIDED: Catch2**, for now. The 52 files with Rust
   `#[test]` modules are the porting checklist for coverage — each gets a
   corresponding Catch2 `TEST_CASE`/`SECTION` as that file's logic is
   ported, rather than a separate test-writing pass at the end.
7. ~~serde replacement~~ **DECIDED: `reflect-cpp`**
   (https://github.com/getml/reflect-cpp) for struct definitions and
   validation. Its scope narrowed after decision 9 below — see Section 3b
   for why it's no longer the manifest-parsing path, just the typed-struct
   layer underneath.
8. ~~Manifest format~~ **DECIDED: Lua, not YAML/TOML.** Manifests are `.lua`
   files returning a table that mirrors the current YAML shape 1:1. YAML/TOML
   support is **dropped entirely**, not kept for migration. See Section 3b
   for the full design and the real-world break this causes for existing
   Comtrya manifests.
9. ~~Tera templating~~ **DECIDED: dropped**, as a direct consequence of
   decision 8. `{{ expr }}` string templates were working around YAML being
   static; Lua manifests don't need a second templating layer on top of an
   already-dynamic language. `read_file_contents` and similar become plain
   Lua functions registered on the manifest sol2 state. See Section 3b.

## 5. Phased build order

Ordered by dependency, not by difficulty — each phase needs the previous one:

1. **Foundation:** sol2-managed Lua state setup, `Action`/`Atom`/`Step`
   interfaces, `Manifest` struct + sol2-table-to-struct conversion (Section
   3b — reflect-cpp defines the struct shape, sol2 does the actual table
   walk), `Contexts` (env/os/user/privilege detection).
2. **Manifest loading:** local file provider that executes `.lua` manifest
   files via sol2, DAG construction + topological walk (replaces petgraph —
   hand-rolled, small).
3. **Condition evaluation:** Lua-based `ConditionEvaluator` (Section 3a) —
   needed early because `ConditionalVariantAction` sits on top of every
   single action's `where:`/`variants:` handling.
4. **Easy actions first** (no external deps beyond filesystem): `directory.*`,
   `file.copy/remove/link`, `command.run`. These validate the whole
   plan→step→execute pipeline end-to-end before tackling anything exotic.
5. **Package providers** (13 of them — aptitude, dnf, homebrew, winget,
   zypper, pkgin, snapcraft, xbps, bsdpkg, macports, yay, paru): mechanical,
   each ~80-260 lines, mostly shelling out to the relevant package manager
   CLI with different flag conventions.
6. **User/group providers** (linux/macos/freebsd/none × user and group):
   direct POSIX syscalls, no external deps needed.
7. **Network-touching actions:** `file.download`, `binary.github` (HTTP via
   libcurl/cpr), `git.clone` (libgit2).
8. **Plugin system:** Lua embedding (sol2), the part of the codebase that
   most benefits from C++'s mature Lua binding ecosystem vs. Rust's.
9. **CLI shell (`app/`):** argument parsing, `apply`/`status`/`contexts`/
   `version`/`gen-completions` commands, tying everything together.
10. **`jsonschemagen`** (the 3rd crate, schema generation for editor
    tooling) — lowest priority, can be deferred or dropped since it's a
    dev-tooling nicety, not core functionality.

## 6. Honest scope estimate

~12,000 lines of source Rust does not mean ~12,000 lines of C++ — manual
serialization and more verbose C++ syntax will likely make the port *larger*
in raw line count, plausibly 15,000–20,000 lines. This is a genuinely
multi-week effort done carefully, even with AI-assisted code generation,
because each of the ~50 action/atom/provider files needs both translation
and verification against real system behavior (package managers, user
creation, file permissions) that's easy to get subtly wrong.

The good news from actually reading the source: there's no deep algorithmic
cleverness here and no single overwhelming dependency wall — it's breadth
(many small OS-interaction modules) rather than depth. That makes it very
parallelizable: once the foundation (Section 5, phases 1-4) is solid, the
package providers and user/group providers in particular are independent of
each other and can be done in any order, one file at a time, each one
testable in isolation.

## 7. Recommended immediate next step

All decisions from Section 4 are now resolved: CMake, C++20, `tl::expected`,
Catch2, sol2 for Lua (manifests + conditions + plugins, replacing both Rhai
and the original YAML/TOML format), `reflect-cpp` for struct
definitions/validation, Tera dropped, `age` dropped. Nothing structural is
left to decide before writing code.

Next concrete step: build Phase 1+2+4 (foundation, manifest loading, the
easy filesystem actions) as a working proof of concept that can load a
real **`.lua` manifest** (per Section 3b's format) via sol2 and execute
`directory.create` + `file.copy` end to end, with a couple of Catch2 tests
ported alongside (e.g. the `manifests::test`
module's `get_manifest_name` cases — small, pure, no I/O, good first port).
That validates the architecture and the full toolchain (CMake + vcpkg +
tl::expected + Catch2 all wired together and building) before sinking time
into the long tail of package-manager and user-provider translations.
