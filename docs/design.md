# mdot — Design

Status: draft v1 (2026-10-06). Supersedes [archive/comtrya-port-plan.md](archive/comtrya-port-plan.md).

## 1. Why

The user's current dotfiles (`~/dotfiles-v2`) use a personal comtrya fork. Before that they used GNU stow. Neither fits:

- **stow** only links files. It doesn't record which packages a config needs.
- **comtrya** is a general provisioning tool:
  - Every config ends up as a `file.link` action wrapped around a `before: package.install` block. The real unit ("this config belongs to this package") isn't modeled.
  - Nothing tracks removal or drift. If you delete a manifest entry, the link and package stay behind and no one knows.
  - AUR support is a Lua plugin wrapped around `makepkg` (`plugins/aur.lua`), and bootstrapping paru is awkward.
  - Plan, dry-run and error output are weak.

mdot is a **declarative dotfile/config manager** in the spirit of NixOS/home-manager, without Nix:

- The repo describes the desired state.
- mdot computes a diff against what it deployed last time and against the live system.
- It applies that diff, and it can roll back.

## 2. Philosophy

These rules decide every later design question:

1. **No built-in knowledge.** mdot ships no database of where software keeps its config or what a package is called on each distro. The user writes all of that in specs.
2. **Ambiguity is a hard error.** mdot never guesses. Examples: both the repo slot and the target exist; two specs share a name; a `depends` cycle.
3. **Nothing destructive without consent.** Deleting, overwriting or uninstalling needs confirmation, unless the user's own `on_remove` policy says otherwise.
4. **Loading is pure.** Evaluating specs has no side effects, so `mdot plan` is always safe to run.
5. **"User's fault" boundary.** If specs declare paths that conflict from the target software's point of view (e.g. both `~/.vimrc` and `~/.vim/vimrc`), mdot doesn't try to detect it.

## 3. Stack

| Concern | Choice |
|---|---|
| Language | C++20 |
| Build | CMake + vcpkg (manifest mode) |
| Config language | Lua 5.4 via sol2 (plain Lua, no syntax extensions) |
| Errors | `tl::expected<T, Error>` |
| Tests | Catch2 |
| CLI | CLI11 |
| Logging | spdlog / fmt |
| State files | nlohmann-json |
| Structural editing | tree-sitter (+ vendored grammars) |
| Git | shell out to system `git` (no libgit2) |

## 4. Repository layout and loading

```
dotfiles/
  config.lua        -- runs first: vars, global defaults
  specs/**/*.lua    -- auto-merged; each file returns a spec or a list of specs
  configs/          -- mirror root for dirs.home_config  (~/.config)
  home/             -- mirror root for dirs.home         (~)
  data/             -- mirror root for dirs.home_data    (~/.local/share)
  system/etc/       -- mirror root for dirs.etc          (/etc)      [system scope]
  templates/        -- base files for render()
```

**How auto-merge works** (lazy.nvim style):

1. mdot finds the repo root: `--repo <dir>`, else `$PWD` if it contains `config.lua`, else error.
2. `config.lua` runs in its own environment and returns a table `{ vars = {...}, defaults = {...} }`. Both are optional.
3. mdot globs every `specs/**/*.lua`, in sorted order so error messages come out deterministic. Each file runs in a **fresh `sol::environment`**, so a global set in one spec file can't leak into another.
4. A file returns either one `spec{...}` or a plain Lua list of them. All of them are collected into a single `SpecSet` keyed by `name`. **A duplicate name is an error**, and the error lists both file paths.
5. `depends` edges form a DAG, sorted with a hand-rolled topological sort. A cycle is an error that prints the cycle. File order never matters.
6. Disabled specs (`enabled(false)`) are dropped *after* graph checks. If an enabled spec depends on a disabled one, that's an error.

**Sandbox.** Spec and config environments get `string`, `table`, `math`, `utf8`, `ipairs`/`pairs`/`select`/`type`/`tostring`/`tonumber`/`error`/`assert`/`pcall`, and `require` restricted to the repo. They do **not** get `os.execute`, `io`, `load` of arbitrary files, or `debug`. Read-only helpers come from mdot itself: `env("NAME")` and `exists(path)`.

## 5. Lua API

A spec is a function call that receives a list of *clauses*. Each clause is a plain function call that returns a tagged table, so there's no metatable or syntax trickery:

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

### 5.1 Clauses

| Clause | Meaning |
|---|---|
| `name(str, opts?)` | **Required**, exactly once. Stable identity of the spec. `opts.pkg` (default `true`) means the spec **owns** a package called `str`. `opts.pkg_alts = { ["alt-name"] = { "platform", ... } }` gives per-platform name overrides; mdot falls back to `str` when no platform matches. Platform ids are flat: `arch`, `debian`, `fedora`, `windows`, `termux`, ... |
| `depends(names...)` | References other specs by name. Those specs are loaded first. Their packages are *referenced*, not owned. |
| `enabled(bool)` | Per-machine variation. Any Lua expression over `host`, `os`, `vars`, `env()`. Default `true`. |
| `config(paths...)` | Symlink deployment. Each path is a `dirs.*` location and is handled independently (§6.1). Optional per-call opts: `config(dirs.x["p"], { from = "rel/repo/path", walk = true })`. |
| `render(path, opts)` | Builds a managed **copy** from `opts.base` (repo-relative) plus tree-sitter `opts.edits` (§8). |
| `patch(path, opts)` | Enforces tree-sitter `opts.edits` on a live, app-owned file in place (§8). |
| `sysfile(path, opts)` | System-scope copy with `owner`, `group`, `mode` (§7). |
| `on_remove { files=..., package=... }` | Removal policy for this spec (§9.4). |

**One spec owns at most one package.** That's the rule that makes declarative package management possible:

- A config belongs to exactly one package.
- Other packages are reached only through `depends`.
- A spec with only a name is a package-only spec: `spec { name("hyprshot") }`.
- A config-only spec uses `name("bash-prompt", { pkg = false })`.

### 5.2 Context values

| Global | Content |
|---|---|
| `host` | `{ name = <hostname> }` |
| `os` | `{ family = "linux"/"windows"/..., id = "arch"/"debian"/"termux"/..., version = ... }` from `/etc/os-release` and similar sources |
| `vars` | read-only copy of `config.lua`'s `vars` |
| `dirs` | location roots (below) |

### 5.3 `dirs`

`dirs.<root>["relative/path"]` returns a `Location` userdata `{ root, rel }`. The index is a plain `__index`, valid Lua. Every root has a **mirror directory** in the repo:

| Root | Target | Mirror |
|---|---|---|
| `dirs.home_config` | `$XDG_CONFIG_HOME` (`~/.config`) | `configs/` |
| `dirs.home` | `$HOME` | `home/` |
| `dirs.home_data` | `$XDG_DATA_HOME` (`~/.local/share`) | `data/` |
| `dirs.home_state` | `$XDG_STATE_HOME` | `state/` |
| `dirs.etc` | `/etc` | `system/etc/` |

By default, the repo source for `dirs.home["x"]` is `<mirror>/x`. `config(..., { from = "..." })` overrides that, which covers renamed files like `bashrc.sh` → `~/.bashrc`, but the recommended layout is to keep repo and target names identical.

## 6. Deployment kinds

### 6.1 `config()` — symlinks

A directory slot links the whole directory. `walk = true` instead links every file under the slot individually and creates real directories in between. Use it when the target directory also holds files the app writes itself (`~/.cargo`, krita's files directly in `~/.config`).

First-run behavior, decided per path:

| Repo slot | Target | Action |
|---|---|---|
| exists | exists (not our link) | **error** |
| missing | missing | **error** |
| exists | missing | create symlink |
| missing | exists | **prompt**: adopt (move target into slot, symlink back). Declining stops mdot and prints manual steps |
| exists | our symlink | noop |

### 6.2 `render()` — generated copy

`base` file + edits → output bytes, written as a regular file at the target. mdot records a hash of the output. Use it when the content depends on `vars` or the host (fonts, cursor theme).

### 6.3 `patch()` — enforce nodes in an app-owned file

Some apps rewrite their own config (krita's `kritarc`, many GUI apps). Symlinking or rendering those files fights the app. `patch` only enforces the queried nodes and leaves everything else untouched.

## 7. System scope

- `sysfile()` and any `dirs.etc` target deploy as **root-owned copies with explicit `owner`/`group`/`mode`, never symlinks**. A root-read config that points into a user-writable repo would be a privilege-escalation path.
- `render()` may target system locations. The result is still a copy.
- Privileged steps are collected into one batch. mdot writes the batch to a temp file and runs `sudo mdot --exec-plan <file>`, so there's one prompt per apply. The privileged side re-validates the batch and only executes resources marked `system`.

Systemd units, groups and users are deferred (§12).

## 8. Tree-sitter engine

The jq idea, extended to any language with a tree-sitter grammar:

1. Parse the file with the grammar for `lang`.
2. Run a tree-sitter **S-expression query**, which yields captures.
3. Apply edits to the captured nodes, in reverse byte order so offsets stay valid.
4. Re-parse, then **verify there are no ERROR nodes**. If any exist, that's a hard error and nothing is written.

Edit ops are plain functions that return tables:

| Op | Effect |
|---|---|
| `set(q, value, { capture = "v" })` | replace the text of capture `@v` (default: last capture) |
| `delete(q)` | delete the matched node |
| `insert_after(q, text)` / `insert_before(q, text)` | insert text next to the match |
| `ensure(q, text, { after = q2 })` | if `q` matches nothing, insert `text` after the `q2` match |

Matching rules:

- `q[[...]]` is just a string. `q` exists only for readability and validates the query at load time.
- If a `set` query matches zero nodes, that's an error. Use `ensure` for "add if missing".
- If it matches more than one node, that's an error unless the op has `all = true`. This is philosophy rule #2.

The same engine powers the standalone CLI:

```
mdot query <file> '<query>' [--lang L] [--set VALUE] [--capture NAME] [--in-place]
```

Initial grammars: json, toml, ini, css, yaml, lua. Grammars are vendored and compiled in. The final set is an open question.

## 9. Resource model, plan and diff

### 9.1 Resources

Specs compile into a flat list of **resources**:

| Kind | Identity | Desired | Observed (live) |
|---|---|---|---|
| `Link` | target path | link → repo source | `lstat` + `readlink` |
| `Render` | target path | output hash + bytes | file hash |
| `Patch` | target path + query | the edits | does the query on the live file already yield the desired values? |
| `SysFile` | target path | bytes hash, owner, mode | hash, owner, mode |
| `Package` *(phase 5)* | package name | installed, reason explicit/dep | provider query |

Each resource implements `desired()`, `observe()` and `recorded()`.

### 9.2 The 3-way diff

For each resource identity, the planner compares **desired** (from specs) × **recorded** (from state, i.e. what mdot deployed last time) × **live**:

| desired | recorded | live | result |
|---|---|---|---|
| yes | no | absent | **create** |
| yes | no | present, matches | **adopt into state** (noop on disk) |
| yes | no | present, differs | **conflict** (first-run table, §6.1) |
| yes | yes | matches recorded | **update** if desired ≠ recorded, else **noop** |
| yes | yes | differs from recorded | **conflict: drift**. Someone hand-edited a managed file. Show the diff; `--force` overwrites |
| no | yes | matches recorded | **delete** (per `on_remove`) |
| no | yes | differs from recorded | **conflict**: it was modified since mdot deployed it, so mdot won't delete it silently |

**How diff works for symlinks.** For a `Link`, mdot owns only *the link itself*: whether it exists and where it points. The content lives in the repo and is versioned by git, so content changes are git's job. `mdot status` therefore shows two things:

- mdot's resource diff
- `git status --short` of the repo, which covers edits made through the symlink

### 9.3 Output

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

`apply` refuses to run while conflicts exist, unless they're resolved interactively or with `--force`.

### 9.4 Removal policy

When a spec disappears or becomes disabled, its file is often already deleted, so **mdot records each resource's `on_remove` policy in state at apply time** and uses that recorded policy for the delete.

| Key | Values | Built-in default |
|---|---|---|
| `files` | `"remove"`, `"ask"`, `"keep"` | `"remove"` for links and rendered copies. **Patched files are never touched** (the edit stays; mdot just stops enforcing it) |
| `package` | `"uninstall"`, `"ask"`, `"keep"` | `"ask"` |

`config.lua`'s `defaults.on_remove` overrides the built-in default. A spec's own `on_remove` overrides both.

Deleting a symlink is always safe, because the content is in the repo. Deleting a rendered copy is safe only if live == recorded. Otherwise it's a conflict.

## 10. State and generations (git-based)

The repo already has history in git. Generations reuse it: they record **which commit was applied** and **what was deployed**, but they don't snapshot content.

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
  1. `git worktree add --detach <tmp> <commit of N>`
  2. load specs from that worktree
  3. plan against the current state and live system
  4. show the plan and confirm
  5. apply. Links point into the **main repo path**, never into the temp worktree. Any file whose content differs at the old commit goes through a `render`-style copy, or mdot warns and asks the user to `git checkout` first. See open question Q5.
  6. remove the worktree
- Applying with a dirty tree records `dirty: true`. Rolling back to such a generation warns that it can't be reproduced exactly.

State writes are atomic: write to a temp file, then `rename`.

## 11. CLI

| Command | Purpose |
|---|---|
| `mdot plan [--diff]` | show what apply would do |
| `mdot apply [--yes] [--force]` | execute the plan, write state and a generation |
| `mdot status` | resource drift + `git status` of the repo, read-only |
| `mdot adopt <path> [--name N]` | move an existing target into its mirror slot, symlink it back, and write `specs/<N>.lua` if no spec owns that path |
| `mdot generations` | list generations |
| `mdot rollback [N]` | plan and apply an older generation |
| `mdot query <file> <q> ...` | standalone tree-sitter query/edit (§8) |
| `mdot specs` | list loaded specs, their enabled state and dependency order (debugging) |

Global flags: `--repo <dir>`, `-v`/`-q`, `--color`.

## 12. Architecture

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

The package provider interface is defined in phase 1 so the resource model accounts for it, and implemented in phase 5:

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

- An owned package (`name()` with `pkg = true`) is installed as **explicit**.
- A package reached only through `depends` is installed as a **dependency** (`--asdeps`). It becomes removable once nothing references it, using the provider's own orphan tracking (`pacman -Qdtq`).

## 13. Roadmap

The core config manager comes first. Package handling and the other extras come later.

| Phase | Scope |
|---|---|
| 1 | Skeleton (CMake + vcpkg + CI build). Lua loader + sandbox, `dirs`/`host`/`os`, `config()` links (incl. `walk`, `from`), state file, `plan` / `apply` / `status` / `specs`. User scope only |
| 2 | `adopt`, `on_remove` policies, generations + `rollback` via git worktree, backups |
| 3 | System scope: `sysfile`, `dirs.etc`, sudo batch executor |
| 4 | Tree-sitter engine: `mdot query`, then `render()` and `patch()` |
| 5 | Package providers: pacman, with explicit/dep ownership semantics |
| 6+ | AUR / PKGBUILD-from-git source with bootstrap (no paru needed), hooks, lockfile, secrets, systemd units/groups, other distros/OSes, multi-user |

**Phase 1 acceptance test:** using a fixture repo and a temp `$HOME`:

1. `plan` lists the links to create.
2. `apply` creates them.
3. Running `plan` again shows nothing to do.
4. After deleting a spec file, `plan` shows the removals.
5. A link retargeted by hand shows up as drift in `status`.

## 14. Open questions

- **Q1.** Which grammars ship in v1? Hyprland now uses Lua, so it's covered. kanata's `.kbd` has no maintained grammar.
- **Q2.** Should duplicate spec names stay an error forever, or should a later `extend(name)` clause allow host-specific additions?
- **Q3.** Can `enabled` take a function, evaluated after all specs load (e.g. "enabled if spec X is enabled")?
- **Q4.** Secrets: out of scope until phase 6+. Candidates are `age` via an external CLI and `pass`.
- **Q5.** Rollback for `Link` resources whose *content* changed between commits. Symlinks point into the working tree, so getting the old content back means checking out the old commit. Options: let rollback do `git checkout <commit>` itself (needs a clean tree), or only restore the link *set* and leave content to git.
- **Q6.** Multi-user and system-wide user config (`/etc/skel`, other users' homes) are deferred. `dirs.home` always means the invoking user.
- **Q7.** Unmanaged scripts (`dotfiles-v2/unmanaged/`, `scripts/`): they stay plain scripts in the repo until hooks exist in phase 6+.
- **Q8.** `pkg_alts` debugging: should `mdot specs` show the resolved package name per platform? (Probably yes.)

## Appendix A — dotfiles-v2 translated

This appendix is an expressiveness check against the real comtrya manifests.

**`hyprland.yaml`.** The link plus a package list becomes one spec per package:

```lua
-- specs/hyprland.lua
return {
  spec {
    name("hyprland"),
    depends("hyprpicker", "hyprshot", "cliphist", "awww"),
    config(dirs.home_config["hypr"]),
  },
  spec { name("hyprpicker") },
  spec { name("hyprshot") },
  spec { name("cliphist") },
  spec { name("awww") },
}
```

**`utils.yaml` / `dev-utils.yaml`.** A long tail of packages with no config is just Lua:

```lua
-- specs/cli-tools.lua
local out = {
  spec { name("btop"),    config(dirs.home_config["btop"]) },
  spec { name("bat"),     config(dirs.home_config["bat"]) },
  spec { name("mpv"),     config(dirs.home_config["mpv"]) },
  spec { name("github-cli"), config(dirs.home_config["gh/config.yml"]) }, -- file-level: gh writes hosts.yml itself
}
for _, p in ipairs { "eza", "zoxide", "fzf", "wget", "rsync", "tldr", "unzip", "zip" } do
  out[#out + 1] = spec { name(p) }
end
return out
```

`clangd`'s config with no package (commented out in comtrya) becomes `name("clangd", { pkg = false })`. `.inputrc` becomes `spec { name("inputrc", { pkg = false }), config(dirs.home[".inputrc"]) }`.

**`modules/bash`.** Renamed files and multiple paths:

```lua
return spec {
  name("bash"),
  config(dirs.home_config["bash"]),
  config(dirs.home[".bashrc"],       { from = "configs/bash/bashrc.sh" }),
  config(dirs.home[".bash_profile"], { from = "configs/bash/bash_profile.sh" }),
}
```

**`modules/krita`.** Comtrya uses `walk_dir` into `~/.config`, and krita rewrites `kritarc`:

```lua
return spec {
  name("krita"),
  config(dirs.home_config["kritashortcutsrc"]),          -- static files: link
  patch(dirs.home_config["kritarc"], { lang = "ini", edits = {
    set(q[[(setting (setting_name) @k (#eq? @k "canvasState") (setting_value) @v)]], "OPENGL_SUCCESS"),
  } }),
}
```

The exact krita keys are illustrative.

**`Comtrya.yaml` variables.** These become `vars` + `render`:

```lua
-- config.lua
return {
  vars = { font = "Hack Nerd Font", cursor = { name = "phinger-cursor-dark", size = 16 } },
  defaults = { on_remove = { files = "remove", package = "ask" } },
}
```

```lua
-- specs/waybar.lua
return spec {
  name("waybar"),
  depends("ttf-hack-nerd"),
  config(dirs.home_config["waybar/config.jsonc"]),
  render(dirs.home_config["waybar/style.css"], {
    base = "templates/waybar/style.css", lang = "css",
    edits = { set(q[[(declaration (property_name) @p (#eq? @p "font-family") (plain_value) @v)]], vars.font, { all = true }) },
  }),
}
```

**`modules/kanata`, `tablet.yaml`, `phinger-cursors.yaml`, `paru.yaml`.** These are AUR packages, possibly built from a custom git repo (`NexushasTaken/kanata-bin`). In v1 they're written with config only. Their package source arrives in phase 6, presumably as `name("kanata-bin", { source = aur { repo = "..." } })`; the exact form isn't designed yet. kanata's uinput group/udev setup is system scope (phase 3 for files, phase 6+ for groups).

**`nexos.yaml`.** Its `depends` list of modules and fonts becomes `enabled(host.name == "nexos")` on host-specific specs. Package-only specs cover the fonts and misc packages.

**Coverage result.** Every comtrya construct used in dotfiles-v2 maps to one of:

- an expressible spec today
- phase 3/5/6 features: AUR source, groups, hooks
- open questions Q5 and Q7 (rollback content, unmanaged scripts)

Nothing is silently dropped.
