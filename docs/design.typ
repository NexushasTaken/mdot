#import "template.typ": *

#show: spec.with(
  title: "mdot — Design",
  meta: [Draft spec · 2026-10-06 · Supersedes `archive/comtrya-port-plan.md`],
)

= About this document

This is the *current spec*: what mdot is meant to be, kept short and up to date. Related documents:

- `research.typ`: motivation, related work, design trade-offs, open research questions, planned
  experiments and the dotfiles-v2 translation.
- `adr/`: one record per decision, with its context.

When a decision changes, add a new ADR and update this spec to match.

mdot is a *declarative dotfile/config manager* in the spirit of NixOS/home-manager, without Nix:

- The repo describes the desired state.
- mdot computes a diff against what it deployed last time and against the live system.
- It applies that diff, and it can roll back.

= Philosophy <philosophy>

These rules decide every later design question:

+ *No built-in knowledge.* mdot ships no database of where software keeps its config or what a
  package is called on each distro. The user writes all of that in specs.
+ *Ambiguity is a hard error.* mdot never guesses. Examples: both the repo slot and the target
  exist; two specs share a name; a `depends` cycle.
+ *Nothing destructive without consent.* Deleting, overwriting or uninstalling needs confirmation,
  unless the user's own `on_remove` policy says otherwise.
+ *Loading is pure.* Evaluating specs has no side effects, so `mdot plan` is always safe to run.
+ *"User's fault" boundary.* If specs declare paths that conflict from the target software's point
  of view (e.g. both `~/.vimrc` and `~/.vim/vimrc`), mdot doesn't try to detect it.

= Stack

#table(
  columns: 2,
  [Concern], [Choice],
  [Language], [C++20],
  [Build], [CMake + vcpkg (manifest mode)],
  [Config language], [Lua 5.4 via sol2 (plain Lua, no syntax extensions)],
  [Errors], [`tl::expected<T, Error>`],
  [Tests], [Catch2],
  [CLI], [CLI11],
  [Logging], [spdlog / fmt],
  [State files], [nlohmann-json],
  [Structural editing], [tree-sitter (+ vendored grammars)],
  [Git], [shell out to system `git` (no libgit2)],
)

= Repository layout and loading <layout>

```
dotfiles/
  config.lua              -- optional: runs first, vars
  specs/
    <name>/               -- one directory per spec (flat; no grouping yet)
      spec.lua            -- optional; if present it controls the directory
      ...                 -- the spec's files, any layout
```

A spec is a directory under `specs/`. Its name is the directory name. There are two modes, decided
only by whether `spec.lua` exists:

#table(
  columns: (auto, 1fr),
  [Mode], [Behavior],
  [*Implicit* (no `spec.lua`)],
  [Config-only spec. The whole directory is symlinked to `~/.config/<name>`. It never owns a package.],
  [*Explicit* (`spec.lua`)],
  [`spec.lua` has full control. *Nothing is linked automatically*; every link is declared. `name`
    defaults to the directory name. A `spec.lua` that declares nothing is an error.],
)

```
specs/
  gdb/                    -- implicit: linked to ~/.config/gdb
    gdbinit
  hypr/                   -- explicit: spec.lua says what goes where
    spec.lua
    hyprland.lua
```

Consequences worth knowing:

- Adding a `spec.lua` to an implicit directory turns its automatic link off. `mdot plan` must show
  that link being removed, so the change is never silent.
- Implicit mode only covers `~/.config/<dirname>`. Anything else (`~/.bashrc`, `~/.local/share/...`)
  needs a `spec.lua`.
- *Packages are opt-in.* A directory name is a config name, not necessarily a package name
  (`nvim/` vs `neovim`), so implicit specs never own a package. Ownership is declared in `spec.lua`
  (Phase 5).
- *System scope is parked.* It is deliberately not part of this layout yet. See ADR 0014.

*Loading:*

+ mdot finds the repo root: `--repo <dir>`, else `$PWD` if it contains `specs/`, else error.
+ If `config.lua` exists it runs in its own environment and returns `{ vars = {...} }`.
+ mdot lists `specs/*/` in sorted order, so error messages are deterministic. A directory with a
  `spec.lua` runs it in a *fresh `sol::environment`*, so globals can't leak between specs. A
  directory without one becomes an implicit spec.
+ Specs are collected into a `SpecSet` keyed by name. Names are directory names, so duplicates cannot
  happen.

*Links in `spec.lua`.* The one deployment clause for now is `link(src, dst)`:

```lua
-- specs/bash/spec.lua
return spec {
  link("bashrc", "~/.bashrc"),
}

-- specs/hypr/spec.lua   (files live in specs/hypr/config/)
return spec {
  link("config", "~/.config/hypr"),
}
```

- `src` is a path relative to the spec's directory. `dst` is a plain string; a leading `~` expands
  to `$HOME`.
- A link is always "this path in the spec directory" to "that path on disk", whether it is a file or
  a directory. There are no special modes.
- *`spec.lua` is absolute.* mdot does not exclude or protect anything. `link(".", "~/.config/hypr")`
  is allowed and will link `spec.lua` too. Keeping `spec.lua` out of a target is the author's job,
  which is why the recommended layout for directory targets is a `config/` subfolder.
- A missing `src` is a hard error at load time, before anything touches the system.

*Sandbox.* Spec and config environments get `string`, `table`, `math`, `utf8`,
`ipairs`/`pairs`/`select`/`type`/`tostring`/`tonumber`/`error`/`assert`/`pcall`, and `require`
restricted to the repo. They do *not* get `os.execute`, `io`, `load` of arbitrary files, or `debug`.
Read-only helpers come from mdot itself: `env("NAME")` and `exists(path)`.

= Lua API <lua-api>

A spec is a function call that receives a list of _clauses_. Each clause is a plain function call
that returns a tagged table, so there's no metatable or syntax trickery:

```lua
-- specs/waybar.lua
return spec {
  name("waybar"),
  depends("fonts", "hyprland"),
  enabled(host.name == "nexos"),
  config(dirs.home_config["waybar"]),
  on_remove { files = "remove", package = "ask" },
}
```

== Clauses

#table(
  columns: (auto, 1fr),
  [Clause], [Meaning],
  [`name(str, opts?)`],
  [*Required*, exactly once. Stable identity of the spec. `opts.pkg` (default `true`) means the spec
    *owns* a package called `str`. `opts.pkg_alts = { ["alt-name"] = { "platform", ... } }` gives
    per-platform name overrides; mdot falls back to `str` when no platform matches. Platform ids are
    flat: `arch`, `debian`, `fedora`, `windows`, `termux`, ...],
  [`depends(names...)`],
  [References other specs by name. Those specs are loaded first. Their packages are _referenced_,
    not owned.],
  [`enabled(bool)`],
  [Per-machine variation. Any Lua expression over `host`, `os`, `vars`, `env()`. Default `true`.],
  [`config(paths...)`],
  [Symlink deployment. Each path is a `dirs.*` location and is handled independently
    (@config-links). Optional per-call opts:
    `config(dirs.x["p"], { from = "rel/repo/path", walk = true })`.],
  [`render(path, opts)`],
  [Builds a managed *copy* from `opts.base` (repo-relative) plus tree-sitter `opts.edits`
    (@tree-sitter).],
  [`patch(path, opts)`],
  [Enforces tree-sitter `opts.edits` on a live, app-owned file in place (@tree-sitter).],
  [`sysfile(path, opts)`], [System-scope copy with `owner`, `group`, `mode` (@system-scope).],
  [`on_remove { files=..., package=... }`], [Removal policy for this spec (@removal).],
)

*One spec owns at most one package.* That's the rule that makes declarative package management
possible:

- A config belongs to exactly one package.
- Other packages are reached only through `depends`.
- A spec with only a name is a package-only spec: `spec { name("hyprshot") }`.
- A config-only spec uses `name("bash-prompt", { pkg = false })`.

== Context values

#table(
  columns: (auto, 1fr),
  [Global], [Content],
  [`host`], [`{ name = <hostname> }`],
  [`os`],
  [`{ family = "linux"/"windows"/..., id = "arch"/"debian"/"termux"/..., version = ... }` from
    `/etc/os-release` and similar sources],
  [`vars`], [read-only copy of `config.lua`'s `vars`],
  [`dirs`], [location roots (below)],
)

== `dirs` <dirs>

`dirs.<root>["relative/path"]` returns a `Location` userdata `{ root, rel }`. The index is a plain
`__index`, valid Lua. Every root has a *mirror directory* in the repo:

#table(
  columns: 3,
  [Root], [Target], [Mirror],
  [`dirs.home_config`], [`$XDG_CONFIG_HOME` (`~/.config`)], [`configs/`],
  [`dirs.home`], [`$HOME`], [`home/`],
  [`dirs.home_data`], [`$XDG_DATA_HOME` (`~/.local/share`)], [`data/`],
  [`dirs.home_state`], [`$XDG_STATE_HOME`], [`state/`],
  [`dirs.etc`], [`/etc`], [`system/etc/`],
)

By default, the repo source for `dirs.home["x"]` is `<mirror>/x`. `config(..., { from = "..." })`
overrides that, which covers renamed files like `bashrc.sh` → `~/.bashrc`, but the recommended
layout is to keep repo and target names identical.

= Deployment kinds

== `link()` — symlinks <config-links>

`link(src, dst)` makes `dst` a symlink to `src` (see the layout section). The planner looks at what
is at `dst` and never overwrites anything:

#table(
  columns: (auto, 1fr),
  [`dst` is...], [Result],
  [missing], [create the symlink (and any missing parent directories, below)],
  [a symlink to our `src`], [no-op],
  [a symlink to somewhere else], [*conflict*],
  [a real file or directory], [*conflict*],
  [a dangling symlink], [*conflict*],
)

*A conflict is a hard error.* There is no `--force`. `plan` reports every conflict, and `apply`
re-checks all links before it changes anything, so it never stops half-applied. Each error names the
spec, `src`, `dst` and what was found, for example:

```
error: hypr: cannot link ~/.config/hypr
  expected: missing, or symlink to specs/hypr/config
  found:    symlink to ~/old-hypr
```

If state says mdot created that link, the report adds that it *drifted*. It is still a conflict:
mdot reports it and you fix it. `status` uses the same wording.

*Parent directories.* If a parent of `dst` is missing, mdot creates it and records it in state.
Directories that already existed are never recorded. When the link is removed, mdot tries to remove
the recorded directories, deepest first, with `rmdir` semantics. A directory that is not empty is
left alone and dropped from state, so mdot never deletes a file it doesn't know about.

== `render()` — generated copy

`base` file + edits → output bytes, written as a regular file at the target. mdot records a hash
of the output. Use it when the content depends on `vars` or the host (fonts, cursor theme).

== `patch()` — enforce nodes in an app-owned file

Some apps rewrite their own config (krita's `kritarc`, many GUI apps). Symlinking or rendering those
files fights the app. `patch` only enforces the queried nodes and leaves everything else untouched.

= System scope <system-scope>

- `sysfile()` and any `dirs.etc` target deploy as *root-owned copies with explicit
  `owner`/`group`/`mode`, never symlinks*. A root-read config that points into a user-writable repo
  would be a privilege-escalation path.
- `render()` may target system locations. The result is still a copy.
- Privileged steps are collected into one batch. mdot writes the batch to a temp file and runs
  `sudo mdot --exec-plan <file>`, so there's one prompt per apply. The privileged side re-validates
  the batch and only executes resources marked `system`.

Systemd units, groups and users are deferred (@architecture).

= Tree-sitter engine <tree-sitter>

The jq idea, extended to any language with a tree-sitter grammar:

+ Parse the file with the grammar for `lang`.
+ Run a tree-sitter *S-expression query*, which yields captures.
+ Apply edits to the captured nodes, in reverse byte order so offsets stay valid.
+ Re-parse, then *verify there are no ERROR nodes*. If any exist, that's a hard error and nothing is
  written.

Edit ops are plain functions that return tables:

#table(
  columns: (auto, 1fr),
  [Op], [Effect],
  [`set(q, value, { capture = "v" })`], [replace the text of capture `@v` (default: last capture)],
  [`delete(q)`], [delete the matched node],
  [`insert_after(q, text)` / `insert_before(q, text)`], [insert text next to the match],
  [`ensure(q, text, { after = q2 })`], [if `q` matches nothing, insert `text` after the `q2` match],
)

Matching rules:

- `q[[...]]` is just a string. `q` exists only for readability and validates the query at load
  time.
- If a `set` query matches zero nodes, that's an error. Use `ensure` for "add if missing".
- If it matches more than one node, that's an error unless the op has `all = true`. This is
  philosophy rule 2 (@philosophy).

The same engine powers the standalone CLI:

```
mdot query <file> '<query>' [--lang L] [--set VALUE] [--capture NAME] [--in-place]
```

Initial grammars: json, toml, ini, css, yaml, lua. Grammars are vendored and compiled in. The final
set depends on experiment S1 (`research.typ`, Methodology).

= Resource model, plan and diff <resources>

== Resources

Specs compile into a flat list of *resources*:

#table(
  columns: 4,
  [Kind], [Identity], [Desired], [Observed (live)],
  [`Link`], [target path], [link → repo source], [`lstat` + `readlink`],
  [`Render`], [target path], [output hash + bytes], [file hash],
  [`Patch`], [target path + query], [the edits],
  [does the query on the live file already yield the desired values?],
  [`SysFile`], [target path], [bytes hash, owner, mode], [hash, owner, mode],
  [`Package` _(phase 5)_], [package name], [installed, reason explicit/dep], [provider query],
)

Each resource implements `desired()`, `observe()` and `recorded()`.

== The 3-way diff <three-way>

For each resource identity, the planner compares *desired* (from specs) × *recorded* (from state,
i.e. what mdot deployed last time) × *live*:

#table(
  columns: (auto, auto, auto, 1fr),
  [desired], [recorded], [live], [result],
  [yes], [no], [absent], [*create*],
  [yes], [no], [present, matches], [*adopt into state* (noop on disk)],
  [yes], [no], [present, differs], [*conflict* (first-run table, @config-links)],
  [yes], [yes], [matches recorded], [*update* if desired ≠ recorded, else *noop*],
  [yes], [yes], [differs from recorded],
  [*conflict: drift*. Someone hand-edited a managed file. Show the diff; `--force` overwrites],
  [no], [yes], [matches recorded], [*delete* (per `on_remove`)],
  [no], [yes], [differs from recorded],
  [*conflict*: it was modified since mdot deployed it, so mdot won't delete it silently],
)

*How diff works for symlinks.* For a `Link`, mdot owns only _the link itself_: whether it exists
and where it points. The content lives in the repo and is versioned by git, so content changes are
git's job. `mdot status` therefore shows two things:

- mdot's resource diff
- `git status --short` of the repo, which covers edits made through the symlink

== Output

`mdot plan` prints something like this, grouped by spec in dependency order:

```
waybar
  + link    ~/.config/waybar -> configs/waybar
  ~ render  ~/.config/waybar/style.css   (2 lines changed, --diff to show)
hyprshot
  - link    ~/.config/hyprshot           (spec removed; on_remove.files=remove)
! conflict ~/.config/foot/foot.ini: exists and is not managed (adopt? see `mdot adopt`)

Plan: 1 to create, 1 to update, 1 to delete, 1 conflict.
```

`apply` refuses to run while conflicts exist, unless they're resolved interactively or with
`--force`.

== Removal policy <removal>

When a spec disappears or becomes disabled, its file is often already deleted, so *mdot records each
resource's `on_remove` policy in state at apply time* and uses that recorded policy for the delete.

#table(
  columns: (auto, auto, 1fr),
  [Key], [Values], [Built-in default],
  [`files`], [`"remove"`, `"ask"`, `"keep"`],
  [`"remove"` for links and rendered copies. *Patched files are never touched* (the edit stays;
    mdot just stops enforcing it)],
  [`package`], [`"uninstall"`, `"ask"`, `"keep"`], [`"ask"`],
)

`config.lua`'s `defaults.on_remove` overrides the built-in default. A spec's own `on_remove`
overrides both.

Deleting a symlink is always safe, because the content is in the repo. Deleting a rendered copy is
safe only if live == recorded. Otherwise it's a conflict.

= State and generations (git-based) <generations>

The repo already has history in git. Generations reuse it: they record *which commit was applied*
and *what was deployed*, but they don't snapshot content.

```
$XDG_STATE_HOME/mdot/<repo-id>/      repo-id = hash of the repo's absolute path
  state.json                        current deployed resources + policies + hashes
  generations/0001.json ...         one per successful apply
  backups/<gen>/...                 originals moved aside by --force / adopt
```

A generation record looks like this:

```json
{ "gen": 12, "time": "...", "commit": "2d61fbe...", "dirty": false,
  "host": "nexos", "resources": [ ... ] }
```

- `mdot generations` lists them.
- `mdot rollback [N]` (default: previous generation) runs these steps:
  + `git worktree add --detach <tmp> <commit of N>`
  + load specs from that worktree
  + plan against the current state and live system
  + show the plan and confirm
  + apply. Links point into the *main repo path*, never into the temp worktree. Any file whose
    content differs at the old commit goes through a `render`-style copy, or mdot warns and asks the
    user to `git checkout` first. Unresolved; see research question RQ4.
  + remove the worktree
- Applying with a dirty tree records `dirty: true`. Rolling back to such a generation warns that it
  can't be reproduced exactly.

State writes are atomic: write to a temp file, then `rename`.

= CLI

#table(
  columns: (auto, 1fr),
  [Command], [Purpose],
  [`mdot plan [--diff]`], [show what apply would do],
  [`mdot apply [--yes] [--force]`], [execute the plan, write state and a generation],
  [`mdot status`], [resource drift + `git status` of the repo, read-only],
  [`mdot adopt <path> [--name N]`],
  [move an existing target into its mirror slot, symlink it back, and write `specs/<N>.lua` if no
    spec owns that path],
  [`mdot generations`], [list generations],
  [`mdot rollback [N]`], [plan and apply an older generation],
  [`mdot query <file> <q> ...`], [standalone tree-sitter query/edit (@tree-sitter)],
  [`mdot specs`], [list loaded specs, their enabled state and dependency order (debugging)],
)

Global flags: `--repo <dir>`, `-v`/`-q`, `--color`.

= Architecture <architecture>

```
src/
  lua/       loader: config.lua + specs/** -> SpecSet; sandboxed per-file sol::environment; clause constructors
  model/     Spec, Location/Dirs, Host/OS context, Resource variants
  graph/     depends DAG, topo sort, cycle reporting
  ts/        tree-sitter query + edit engine, grammar registry
  planner/   desired x recorded x live -> Plan; pretty printer
  executor/  apply Plan; privileged batch via sudo re-exec
  state/     state.json, generations, backups (atomic writes)
  vcs/       git shell-out: rev-parse, status, worktree
  platform/  XDG resolution, os-release, PackageProvider interface
  cli/       CLI11 command wiring
tests/       Catch2 unit tests + fixture repos for end-to-end plan/apply
```

The package provider interface is defined in phase 1 so the resource model accounts for it, and
implemented in phase 5:

```cpp
struct PackageInfo { bool installed; std::string version; Reason reason; }; // Reason: explicit|dependency
class PackageProvider {
public:
  virtual ~PackageProvider() = default;
  virtual tl::expected<PackageInfo, Error> query(std::string_view name) = 0;
  virtual tl::expected<void, Error> install(std::span<const std::string> names, Reason) = 0;
  virtual tl::expected<void, Error> remove(std::span<const std::string> names) = 0;
  virtual tl::expected<void, Error> set_reason(std::span<const std::string> names, Reason) = 0;
  virtual tl::expected<std::vector<std::string>, Error> list_explicit() = 0;
};
```

Package semantics:

- An owned package (`name()` with `pkg = true`) is installed as *explicit*.
- A package reached only through `depends` is installed as a *dependency* (`--asdeps`). It becomes
  removable once nothing references it, using the provider's own orphan tracking (`pacman -Qdtq`).

= Roadmap <roadmap>

The core config manager comes first. Package handling and the other extras come later.

#table(
  columns: (auto, 1fr),
  [Phase], [Scope],
  [0],
  [Research experiments S1–S6 (`research.typ`, Methodology). Their results may change this spec
    before Phase 1 is locked],
  [1],
  [Skeleton (CMake + vcpkg + CI build). Lua loader + sandbox, `dirs`/`host`/`os`, `config()` links
    (incl. `walk`, `from`), state file, `plan` / `apply` / `status` / `specs`. User scope only],
  [2], [`adopt`, `on_remove` policies, generations + `rollback` via git worktree, backups],
  [3], [System scope: `sysfile`, `dirs.etc`, sudo batch executor],
  [4], [Tree-sitter engine: `mdot query`, then `render()` and `patch()`],
  [5], [Package providers: pacman, with explicit/dep ownership semantics],
  [6+],
  [AUR / PKGBUILD-from-git source with bootstrap (no paru needed), hooks, lockfile, secrets,
    systemd units/groups, other distros/OSes, multi-user],
)

*Phase 1 acceptance test:* using a fixture repo and a temp `$HOME`:

+ `plan` lists the links to create.
+ `apply` creates them.
+ Running `plan` again shows nothing to do.
+ After deleting a spec file, `plan` shows the removals.
+ A link retargeted by hand shows up as drift in `status`.

= Open questions

Open questions and unproven claims are tracked as research questions in `research.typ` (Research
questions). Known limitations are in `research.typ` (Limitations and future work).
