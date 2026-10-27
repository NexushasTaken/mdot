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
+ *Nothing destructive without consent.* Deleting, overwriting or uninstalling needs confirmation.
+ *Loading is pure.* Evaluating specs has no side effects, so `mdot plan` is always safe to run.
+ *"User's fault" boundary* (widened by ADR 0039). mdot doesn't try to predict mistakes that depend
  on what the user writes: paths that conflict from the target software's point of view (e.g. both
  `~/.vimrc` and `~/.vim/vimrc`), or a marker expression with no value on some host. It reports
  every error it does find, naming the problem.

= Stack

#table(
  columns: 2,
  [Concern], [Choice],
  [Language], [Rust (ADR 0036)],
  [Build], [Cargo],
  [Config language], [Lua 5.4 via mlua, vendored (plain Lua, no syntax extensions)],
  [Errors], [`Result<T, E>` with mdot's own error types],
  [Tests], [`cargo test`],
  [CLI], [clap (derive)],
  [Logging], [`tracing` + `tracing-subscriber`, for user output and debug logs as separate outputs
    (ADR 0059)],
  [State files], [JSON via `serde` + `serde_json` (ADR 0059)],
  [Structural editing], [tree-sitter (+ vendored grammars); Rust binding open (ADR 0036)],
  [Git], [shell out to system `git` (no libgit2)],
)

= Repository layout <layout>

```
dotfiles/
  config.lua              -- optional: runs first, defines mdot.vars
  hosts/
    <hostname>.lua        -- the root of a machine: says which specs it uses
  specs/
    <name>/               -- one directory per spec (flat; no grouping yet)
      spec.lua            -- optional; if present it controls the directory
      ...                 -- the spec's files, any layout
```

A spec is a directory under `specs/`. Its name is the directory name. *A spec in `specs/` is not
applied just because it exists*: it is applied only when a host reaches it through `depends`
(@hosts). There are two modes, decided only by whether `spec.lua` exists:

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
  (`nvim/` vs `neovim`), so implicit specs never need a package. A spec says it needs one with the `package`
  clause in `spec.lua` (Phase 5, ADR 0021).
- *System scope is parked.* It is deliberately not part of this layout yet. See ADR 0014.
- An implicit spec has no `spec.lua`, so it cannot call `depends`. It is always a leaf.

= Hosts and selection <hosts>

`specs/` is a library; a machine says what it wants in `hosts/<hostname>.lua` (ADR 0019):

```lua
-- hosts/nexos.lua
return spec { depends("desktop", "utils", "bash") }

-- specs/desktop/spec.lua   (a spec that only groups others)
return spec { depends("hypr", "waybar", "dunst", "uwsm") }
```

- mdot loads `hosts/<hostname>.lua` and applies every spec reachable from it through `depends`.
  A spec nobody reaches is not applied. If it was applied before, `plan` shows its links as
  removals.
- `depends(names...)` looks names up in *`<repo root>/specs/`*, whichever file calls it. It is never
  relative to the caller, so `hosts/` and `specs/` resolve identically. There is no `import`.
  (File paths in `file.link` are the opposite: relative to the spec's own directory.)
- An unknown name is an error that lists the names it did find. A cycle is an error that names the
  cycle. A spec reached more than once is applied once.
- A host file has no directory, so it only holds selection (`depends`) and overrides of
  `mdot.vars` (ADR 0038, 0042). A `file.link` in a host file is an error.
- `--host <name>` makes `plan` and `status` load `hosts/<name>.lua` instead, as a dry run. `apply`
  with a `--host` that differs from the real hostname is an error. A missing host file is an error
  that lists the files in `hosts/`.

= Loading and sandbox <loading>

*Loading:*

+ mdot finds the repo root: `--repo <dir>`, else `$PWD` if it contains `specs/`, else error.
+ If `config.lua` exists it runs in its own environment and assigns the base values into `mdot.vars`
  (ADR 0038). Without it, base `vars` is empty.
+ mdot loads `hosts/<hostname>.lua` (or `--host`) and then follows `depends` to load only the specs
  it reaches. A directory without a `spec.lua` becomes an implicit spec. Every file (`config.lua`,
  the host file, each `spec.lua`) runs in its own fresh environment, so globals can't leak between
  files (ADR 0048).
+ `specs/*/` is listed in sorted order, so error messages (such as the list of known names) are
  deterministic. Names are directory names, so duplicates cannot happen.
+ The reachable specs are collected into a `SpecSet` keyed by name, in dependency order.
+ Two reachable specs (or two clauses) with the same `dst` are an error naming both. `plan` reports
  every error it finds, and `apply` stops before the first write if the plan has any (ADR 0021).

*Sandbox.* The sandbox is for purity, not security (ADR 0013). It is an allowlist: spec and config
environments get `string`, `table`, `math`, `utf8`, and `pairs`/`ipairs`/`next`/`select`/`type`/
`tostring`/`tonumber`/`error`/`assert`/`pcall`/`setmetatable`/`getmetatable`/`print`. Nothing else is
reachable, including `io`, `os`, `debug`, `coroutine`, `package`/`require`, `load`, `dofile`,
`loadfile` and `string.dump`. There are no live-state helpers (no `env()`, no `exists()`), so
`plan` and `apply` load the same clauses.

*Isolation between files* (ADR 0048). Every file runs in its own fresh environment that holds only
what mdot puts in it. Everything mdot puts in it is read-only, except that `config.lua` and the host
file may write `mdot.vars` and `mdot.opt` (ADR 0038, 0045). `config.lua` and host files follow the
same rules as specs. Writing to a library table is an error naming the file, the line and the key
(`a/spec.lua:1: cannot set string.upper`). `getmetatable("")` returns a locked marker, so the real
`string` table cannot be reached through a string. Known quirk: `next(string)` is `nil` and
`#math` is `0`; `pairs(string)` works.

*No `require`* (ADR 0049). Files cannot share helper modules; a helper lives in the file that uses
it, and `mdot.vars` holds only data (a function in base vars is an error). Revisit when the same helper
is copied into a second file, or `config.lua` becomes painful as one file.

Open: mdot's replacement for `print`.

= Lua API <lua-api>

A `spec.lua` returns a plain table of _clauses_. Each clause is an ordinary function call that
returns a tagged value; it does not do anything by itself:

```lua
-- specs/hypr/spec.lua
return spec {
  file.link("config", "~/.config/hypr"),
}
```

*Clauses are declarations.* Calling `file.link(...)` builds a description of a link and returns it. mdot
collects the returned table after the file has run, then decides what to do with it and when:
validation, planning, ordering and execution are all mdot's job (ADR 0018). `spec.lua` never touches
the system, so loading stays pure. Arguments are still ordinary Lua values, evaluated when the
file loads.

*Helpers and nesting.* An entry in `spec { ... }` may also be a list of clauses, so a helper
function can return several `file.link()`s. mdot flattens such lists in order before it reads them. Any
other entry is an error that names its position (ADR 0018):

```lua
local function user_units(...)
  local out = {}
  for _, f in ipairs({...}) do
    out[#out + 1] = file.link(f, "~/.config/systemd/user/" .. f)
  end
  return out
end

return spec {
  user_units("i3-session.service", "i3-session.target", "kanata.service"),
}
```

A spec in explicit mode is a `spec.lua` like this one (@layout). Implicit specs have no Lua at all.

== Clauses

*Designed:*

#table(
  columns: (auto, 1fr),
  [Clause], [Meaning],
  [`file.link(src, dst)`],
  [Symlink deployment: `dst` becomes a symlink to `src`, relative to the spec directory
    (@config-links).],
  [`file.link { names..., into = dir, dot? }`],
  [Batch form of `file.link`: each name is linked to `dir/<name>`, or `dir/.<name>` with `dot = true`
    (ADR 0022).],
  [`net.download { url, dst, sha256 }`],
  [Fetch one file at `apply` time and check its hash (@net-download, ADR 0024). Also accepts
    `hash = "algo:hex"` or `verify = false` in place of `sha256`, and an optional `mode`. Not part of
    Phase 1.],
  [`depends(names...)`],
  [Names other specs from `<repo root>/specs/` that this one needs. A host or group spec uses it to
    select specs; any spec can use it to pull in what it needs (ADR 0019, @hosts). Unknown names and
    cycles are errors. Packages will use it for install reasons (Phase 5).],
)

A spec's identity is its directory name (ADR 0021); there is no `name()` clause.

*Groups.* Clauses that put a managed resource on the system live in a group named after what they
act on, written `group.clause(...)`: `file.link` and `net.download`, later `file.copy`. Clauses that
describe the spec itself (`depends`, `enabled`, `package`, `config`) stay flat. The rule
is not strict: a clause is grouped only where the group name reads naturally (`file.depends` would
not). Whatever the group, every resource clause produces the same kind of resource, so the `dst`
conflict rules apply across groups.

*Planned, not designed yet.* These are not part of Phase 1, and their syntax may change:

#table(
  columns: (auto, 1fr, auto),
  [Clause], [Purpose], [Phase],
  [`file.copy(src, dst)`], [Copy a file from the spec directory instead of linking it.], [—],
  [`sysfile(...)`], [Root-owned copies (@system-scope). On hold, see ADR 0014.], [3],
  [`render(...)`, `patch(...)`], [Tree-sitter editing (@tree-sitter).], [4],
  [marker clause (name open)], [Yolk-style markers evaluated in place in the repo file
    (@markers, ADR 0037).], [—],
  [`package(name?, opts?)`], [The spec needs a package. No arguments means the spec's directory
    name; `opts` carries `pkg_alts` per-platform names (ADR 0021, @packages).], [5],
)

== Context values

`env()` is dropped (ADR 0013).

*The `mdot` global* (ADR 0038). Values mdot hands to Lua live in one global table, in the style of
Neovim's `vim`. The old `host` global is removed (ADR 0040). Its members are `mdot.os`, `mdot.dirs`, `mdot.vars` and `mdot.opt`. There is no `mdot.g`;
`mdot.vars` covers it (ADR 0046). Reading or writing any other member is an error naming it.

*No alias* (ADR 0041). `mdot` is the only name. For a shorter one, use a local:
`local v = mdot.vars`. A local refers to the same table, so it gets the same read-only and schema
checks as `mdot`.

*`mdot.os`* (ADR 0040, 0044). Facts about the machine. A value that does not exist on this OS is
`nil`. Ids are lowercase.

#table(
  columns: 3,
  [*Field*], [*Value*], [*Example*],
  [`name`], [Rust's `std::env::consts::OS`], [`linux`, `windows`, `macos`, `android`],
  [`family`], [Rust's `FAMILY`], [`unix`, `windows`],
  [`arch`], [Rust's `ARCH`], [`x86_64`, `aarch64`],
  [`bitness`], [a number], [`64`],
  [`distribution`], [Linux: `ID=` of `/etc/os-release`; `nil` elsewhere], [`arch`, `debian`],
  [`version`], [a string as the OS reports it; `nil` if none], [`"14.5"`; `nil` on Arch],
  [`codename`], [a string as the OS reports it; `nil` if none], [`nil` on Arch],
  [`edition`], [a string as the OS reports it; `nil` if none], [`nil` on Arch],
  [`hostname`], [see below], [`"laptop"`],
)

- Every field describes the real machine, even under `--host`, except `hostname`.
- `mdot.os.hostname` is exactly the `<name>` mdot used to select `hosts/<name>.lua`: the real
  hostname, or the `--host` value (`plan --host laptop` gives `"laptop"`).
- `config.lua`, host files and specs may all read it. Writing to `mdot.os` is an error naming the
  file. Reading a field it does not have (`mdot.os.hostnme`) is an error naming the field.
- A hostname branch in a spec puts a per-host difference outside the host file; that is allowed.
- *Warning:* a hostname or OS branch in `config.lua` makes base `vars` differ per machine, so the
  markers' clean filter commits different values on different machines. That is the user's fault
  (ADR 0039).

*`mdot.dirs`* (ADR 0043). The common dirs of the real machine, resolved by mdot before loading:

- 19 names: `home`, `cache`, `config`, `config_local`, `data`, `data_local`, `executable`,
  `preference`, `runtime`, `state`, `audio`, `desktop`, `document`, `download`, `font`, `picture`,
  `public`, `template`, `video`. Each value is what the `dirs` crate's function of that name plus
  `_dir` returns on this OS (`config` is `$XDG_CONFIG_HOME` or `~/.config` on Linux), as an
  absolute path string without a trailing separator.
- A dir that does not exist on this OS is `nil` (`state` and `executable` exist only on Linux), so
  `mdot.dirs.state or mdot.dirs.data_local` works. Reading a name not in the list is an error
  naming the field. Writing to `mdot.dirs` is an error naming the file.
- `config.lua`, host files and specs may all read it. `--host` does not change it.
- mdot knows the common dirs, not where each program keeps its config: a spec for a program with a
  different location per OS chooses it itself. Implicit specs still link to `~/.config/<name>`
  (ADR 0020).
- *Warning:* a dir used in `config.lua`'s vars makes base `vars` differ per machine, as with a
  hostname branch.

```lua
file.link("config", mdot.dirs.config .. "/nvim")
```

*`mdot.vars`:*

- `config.lua` is the only file that defines vars. Its `mdot.vars` is the *base `vars`*, which the
  markers' git clean filter evaluates with (ADR 0037). Specs cannot declare defaults (ADR 0042).
- The host file may only override existing keys: `mdot.vars.cursor.size = 24`.
- Specs only read `mdot.vars`. A spec that writes to it is an error naming the spec.
- *Typed by a schema* (ADR 0039). mdot builds a schema from the base `mdot.vars` and checks the
  host's overrides against it. All errors are reported in one run, each naming the key path and
  the host file.
  - A *record* (string keys) keeps exactly the base's keys, and each value keeps its base type.
  - A *list* (keys exactly `1..n`) holds one element type. A host may change its length, not its
    element type. In a list of records, every element matches the base's first element.
  - Integers and floats are one type, `number`.
  - In base, an empty `{}`, a mixed table (`{ "A", x = 1 }`) or a list with gaps is an error.

```lua
-- config.lua
mdot.vars.font = "Hack Nerd Font"
mdot.vars.cursor = { name = "phinger-cursor-dark", size = 16 }

-- hosts/tablet.lua
mdot.vars.cursor.size = 24
return spec { depends("desktop") }
```

*`mdot.opt`* (ADR 0045). mdot's own settings. There is no `mdot.o`.

- Built-in default, then `config.lua`, then the host file; the last write wins. Assigning a leaf
  (`mdot.opt.group.key = value`) changes only that key. A host may set an option
  `config.lua` never set.
- Each option is either host-overridable or `config.lua` only. An option that changes committed
  content must be `config.lua` only.
- Setting an unknown option, a value outside its allowed set, or a `config.lua`-only option in a
  host file is an error naming the option and the file. All errors are reported in one run.
- Specs may read `mdot.opt`. A spec that writes to it is an error naming the spec.
- Command-line flags have no matching options (ADR 0047). If one is added later (a new ADR and a
  row below), the order is flag, then host file, then `config.lua`, then built-in default.

There are no options yet: its only rows, `on_remove.files` and `on_remove.package`, were removed
with the removal policy (ADR 0061). Open: whether an empty `mdot.opt` ships in Phase 1, or the
mechanism waits for its first option.

*Open* (ADR 0038, 0045): `mdot.env`, which would replace part of ADR 0013; on hold until a real
spec needs it. The marker filter default's "Set by" class (ADR 0037).

= Resource kinds

What each resource clause declares and how it acts on disk. How each kind is planned (its
desired × recorded × live table) is in @three-way.

== `file.link()` — symlinks <config-links>

`file.link(src, dst)` makes `dst` a symlink to `src`. It has two forms:

```lua
-- specs/bash/spec.lua
return spec {
  file.link("bashrc", "~/.bashrc"),
}

-- specs/hypr/spec.lua   (files live in specs/hypr/config/)
return spec {
  file.link("config", "~/.config/hypr"),
}

-- specs/x11/spec.lua   (several files, same name as the target, with a leading dot)
return spec {
  file.link { "Xresources", "xinitrc", "xsession", "gtkrc-2.0", into = "~", dot = true },
}

-- specs/systemd-user/spec.lua   (several files into one directory)
return spec {
  file.link { "i3-session.service", "i3-session.target", "kanata.service",
         into = "~/.config/systemd/user" },
}
```

- `file.link(src, dst)` takes two strings and is the form for renames. `file.link { names..., into = dir }`
  links each name to `dir/<name>`; `dot = true` makes that `dir/.<name>`. Any other call is an error
  (ADR 0022). The batch form expands to one link per name, and everything below applies to each
  of them.
- `src` is a path relative to the spec's directory. `dst` and `into` are plain strings; a leading `~`
  expands to `$HOME`.
- A link is always "this path in the spec directory" to "that path on disk", whether it is a file or
  a directory. There are no special modes.
- *`spec.lua` is absolute.* mdot does not exclude or protect anything. `link(".", "~/.config/hypr")`
  is allowed and will link `spec.lua` too. Keeping `spec.lua` out of a target is the author's job,
  which is why the recommended layout for directory targets is a `config/` subfolder.
- A missing `src` is a hard error at load time, before anything touches the system.
- The planner looks at what is at `dst` and never overwrites anything (links table in @three-way).

*Parent directories.* If a parent of `dst` is missing, mdot creates it and adds it to the
top-level `created_dirs` list in state (ADR 0060), not to the link's record. Directories that
already existed are never recorded. After the delete phase, mdot tries to remove each recorded
directory that no remaining record's `dst` is under, deepest first, with `rmdir` semantics. Usage
is derived from the records, never counted, so two links sharing a new parent don't leak it. A
directory that is not empty is left alone, warned about and dropped from state, so mdot never
deletes a file it doesn't know about.

== `net.download()` — pinned downloads <net-download>

Fetches one file over the network and writes it as a regular file at `dst` (ADR 0024). It is a fallback
for things no package provides, and it is not part of Phase 1. The network is used only during
`apply`; spec loading and `plan` stay offline.

```lua
net.download { url = "https://example.org/kanata", dst = "~/.local/bin/kanata",
               sha256 = "<hex>", mode = "755" }
net.download { url = "...", dst = "...", hash = "sha512:<hex>" }
net.download { url = "...", dst = "...", verify = false }
```

#table(
  columns: (auto, 1fr),
  [Field], [Meaning],
  [`url`, `dst`], [Required. `dst` expands like `file.link`'s (ADR 0020).],
  [`sha256`], [Expected hash. The default way to verify.],
  [`hash`], [`"<algo>:<hex>"`, the algorithm is whatever precedes the first `:`. An unknown algorithm is
    an error at spec load.],
  [`verify`], [Defaults to `true`. With `true`, exactly one of `sha256` and `hash` is required (both or
    neither is an error). With `false`, neither may be present. Skipping verification has to be
    written down.],
  [`mode`], [Optional, for example `"755"`. Applied before the final rename. Not part of the content key.],
)

*Content key.* The desired content key `D` is the hash when verified, and the `url` when
`verify = false`. (ADR 0024 and ADR 0032 call it the download's _identity_; it was renamed so that
"identity" means only the resource ID, ADR 0034.)
Both are known without the network, which is why `plan` can stay offline. Updating a verified download
means changing both `url` and the hash.

*Where hashing happens.* Only in `apply` and in `mdot verify`. `plan` and `status` never read file
contents, because the file can be gigabytes and the machine slow.

- `apply` writes the download to a temporary file next to `dst` and hashes the bytes as they arrive
  (no second pass). A mismatch deletes the temporary file, leaves `dst` alone and fails that
  resource. A match renames it over `dst`. With `verify = false` the digest is only recorded.
- State records the content key `R`, the sha256 of the written bytes `W`, and the file's `size`,
  `mtime_ns` and `inode` right after the rename.

*`mdot verify`* hashes the downloads that `plan` reported as conflicts (or all of them with a flag
that ignores the stat cache). With the live hash `L`, the recorded hash `W` and the verified hash `D`:

- `L == D` or `L == W`: the file is fine and only its metadata moved. mdot refreshes the recorded
  stat and the conflict disappears. With no record, this adopts the file if `L == D`.
- Otherwise the file is reported as modified. Nothing on disk changes.

So `verify` writes state but never touches `dst`. A `verify = false` file with no record cannot be
adopted, since there is nothing to compare it with.

*Shared with `file.copy`* (ADR 0026, ADR 0032). The stat record, the plan table, `verify` and `mode` are one
mechanism for every clause that writes a regular file. The permission bits are part of the recorded
stat, so a hand `chmod` is a conflict. A `mode` in the spec that differs from the recorded one, with
the same content key, is an update that only runs `chmod`. `file.copy` itself is not designed.

*Known costs.*

- After `rsync`, a backup restore or `cp` without `-p`, mtimes change and every download shows as a
  conflict until `mdot verify` runs once. A content change that keeps size, mtime and inode is only
  found by a full `verify`. Git's index makes the same trade.
- A `verify = false` download from a moving URL such as `latest` is fetched once and never updated,
  since its content key never changes.
- Archives cannot be extracted yet, so a tarball (such as a cursor theme) needs a package until
  extraction is designed.

*Not designed.* A checksum file URL (such as `SHA256SUMS`), signatures, extraction, mirrors, a download
cache, authentication, proxies and retries. Open: which algorithms beyond sha256, and the HTTP
client and hash library (ADR 0036).

= Templating

Templating has several engines, one clause each (ADR 0037). `render` and `patch` are the
tree-sitter engines; markers are the first other engine.

== `render()` — generated copy

`base` file + edits → output bytes, written as a regular file at the target. mdot records a hash
of the output. Use it when the content depends on `vars` or the host (fonts, cursor theme).

== `patch()` — enforce nodes in an app-owned file

Some apps rewrite their own config (krita's `kritarc`, many GUI apps). Symlinking or rendering those
files fights the app. `patch` only enforces the queried nodes and leaves everything else untouched.

== Markers — Yolk-style templating <markers>

A marker in a comment holds a Lua expression, and mdot rewrites the value it points at.

```
export XCURSOR_SIZE=16   # {< replace_number(vars.cursor.size) >}
```

- `{< ... >}` acts on its own line, `{# ... #}` on the next line.
- *In place (Mode A):* mdot evaluates the markers with this host's values and rewrites the repo
  file itself. The `link` clause still points at that file. Rendering to a copy (Mode B) is later.
- A marker that finds nothing to replace is an error, and nothing is written.
- *Replace functions* (ADR 0039), with strict parameter types; any other argument, including `nil`,
  is an error. More are added when a real file needs one.
  - `replace_quoted(v)`: `v` is a string or a number; replaces the text inside the quotes.
  - `replace_number(v)`: `v` is a number; replaces the number with `tostring(v)`.

  A marker that may index past the end of a list needs a fallback: `vars.fonts[3] or "C"`.
- *Git clean filter* (designed, built later): git stores each marker's *canonical value*, the
  marker evaluated with the base `vars`, while the working tree keeps the host's value. The clean
  step is pure and runs in the ADR 0013 sandbox. It can be turned off per file.

*Open* (ADR 0037): the clause name, the filter option's default and scope,
registering the filter on a fresh clone, and the resource-model table. Base and per-host `vars` are
settled by ADR 0038.

== Tree-sitter engine <tree-sitter>

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
  [`Link`], [kind + target path], [link → repo source], [`lstat` + `readlink`],
  [`Render`], [kind + target path], [output hash + bytes], [file hash],
  [`Patch`], [kind + target path + query], [the edits],
  [does the query on the live file already yield the desired values?],
  [`Download`], [kind + target path], [content key: hash, or `url` when `verify = false`],
  [`stat` compared with the recorded `size`/`mtime_ns`/`inode` (no hashing)],
  [`SysFile`], [kind + target path], [bytes hash, owner, mode], [hash, owner, mode],
  [`Package` _(phase 5)_], [kind + package name], [installed, reason explicit/dep], [provider query],
)

Each resource implements `desired()`, `observe()` and `recorded()`.

An ID is a string `<kind>:<output>`, one per output of a clause; a package's ID has no version
(ADR 0054). Every resource also occupies a *slot*, `<world>:<output>` (`fs:~/.foo`,
`pacman:hyprland`): the place it takes. Two clauses with the same slot are a conflict (ADR 0021).
The spec is not part of the ID; each record stores its owning spec as a plain field that the planner
never compares, so renaming a spec directory is an update (ADR 0055). Paths in IDs and slots are
expanded, absolute and lexically normal (ADR 0056).

*Every kind has its own table* (ADR 0009) in desired × recorded × live form. Before a kind gets one,
it defines its identity, what live observes (and how expensive that is), what "matches" means, and
what is recorded. Kinds with no observable result, such as running a command, do not fit this model;
that is open.

== The 3-way diff <three-way>

For each resource identity, the planner compares *desired* (from specs) × *recorded* (from state,
i.e. what mdot deployed last time) × *live*. Desired and recorded are first matched by ID (ADR 0034).
A generic step then classifies each ID into a case, and the kind decides the action from its own
table; the plan is data that `apply` runs later (ADR 0035). The algorithm is in `planner.typ`.

*Conflicts.* A conflict is a hard error. There is no `--force` (ADR 0016). `plan` reports every
conflict, and `apply` re-checks all resources before it changes anything, so it never stops
half-applied. Each error names the spec, `src`, `dst` and what was found, for example:

```
error: hypr: cannot link ~/.config/hypr
  expected: missing, or symlink to specs/hypr/config
  found:    symlink to ~/old-hypr
```

If state says mdot created that resource, the report adds that it *drifted*. It is still a
conflict: mdot reports it and you fix it. `status` uses the same wording.

=== Common pattern

The table below is the common pattern; each kind's own table governs:

#table(
  columns: (auto, auto, auto, 1fr),
  [desired], [recorded], [live], [result],
  [yes], [no], [absent], [*create*],
  [yes], [no], [present, matches], [*adopt into state* (noop on disk)],
  [yes], [no], [present, differs], [*conflict*],
  [yes], [yes], [matches recorded], [*update* if desired ≠ recorded, else *noop*],
  [yes], [yes], [differs from recorded],
  [*conflict: drift*. Someone hand-edited a managed file. Show the diff. An error for now; there is no `--force` (ADR 0016)],
  [no], [yes], [matches recorded], [*delete*],
  [no], [yes], [differs from recorded],
  [*conflict*: it was modified since mdot deployed it, so mdot won't delete it silently],
)

=== Links

(ADR 0030, @config-links.) A link "matches" when its `readlink` string equals the absolute,
normalized `src`. With no record, "anything else" covers a symlink to somewhere else, a real file
or directory, and a dangling symlink.

#table(
  columns: (auto, auto, auto, 1fr),
  [desired], [recorded], [live], [result],
  [yes], [no], [absent], [*create* (and any missing parent directories)],
  [yes], [no], [link → desired `src`], [*adopt* into state (nothing changes on disk)],
  [yes], [no], [anything else], [*conflict*],
  [yes], [yes], [link → recorded `src` = desired `src`], [*noop*],
  [yes], [yes], [link → recorded `src` ≠ desired `src`], [*update*: replace mdot's own link],
  [yes], [yes], [absent], [*re-create*; the plan shows it was removed by hand],
  [yes], [yes], [link → desired `src` ≠ recorded `src`], [*adopt*: update the record, nothing changes on disk],
  [yes], [yes], [anything else], [*conflict: drift* (ADR 0016)],
  [no], [yes], [link → recorded `src`], [*delete*],
  [no], [yes], [absent], [*forget*: try the recorded `rmdir`s, drop the record; the plan shows it],
  [no], [yes], [anything else], [*conflict*],
)

Re-creating a missing link is a narrow exception to ADR 0016: nothing at that path can be lost. A
link that points elsewhere is still a conflict.

*How diff works for symlinks* (ADR 0031). For a `Link`, mdot owns only _the link itself_: whether
it exists and where it points. An edit made through the link edits the repo file, so it is never
reported by `plan` or `status`; it is a change to the repo, not drift. A user who wants content
history keeps the repo in git. `mdot status` shows only mdot's resource diff. The repo does not have
to be a git repository.

=== Downloads

(ADR 0032, @net-download.) "Stat matches" means the live size, mtime, inode and permission bits
equal the recorded ones. That says the file is unchanged since mdot wrote it, so the record still
describes it. The check can say "unchanged" but never "equal", so when unsure it reports a
conflict. `R` is the recorded content key and `D` the desired one:

#table(
  columns: (auto, auto, auto, 1fr),
  [desired], [recorded], [live], [result],
  [yes], [no], [absent], [*create*],
  [yes], [no], [present], [*conflict*: "unknown, run `mdot verify`"],
  [yes], [yes], [stat matches, `R == D`, same `mode`], [*noop*],
  [yes], [yes], [stat matches, `R == D`, `mode` differs], [*update*: `chmod` only],
  [yes], [yes], [stat matches, `R != D`], [*update*: download again],
  [yes], [yes], [stat differs], [*conflict*: "changed, run `mdot verify`"],
  [yes], [yes], [absent], [*re-create*; the plan shows it was removed by hand and will be downloaded again],
  [no], [yes], [stat matches], [*delete*],
  [no], [yes], [stat differs], [*conflict*],
  [no], [yes], [absent], [*forget*: drop the record; the plan shows it],
)

`plan` never adopts a download with no record, since that needs a hash; `mdot verify` does.
`apply` never overwrites a conflict. Removal is covered by the "not desired" rows; run
`mdot verify` first if a conflict there is only moved metadata.

== Removal <removal>

*There is no removal policy* (ADR 0061, superseding ADR 0011). When a spec disappears or becomes
disabled, each of its recorded resources gets its kind's "not desired" rows in the tables above:
deleted if it is still what mdot left, a conflict if it changed, forgotten if it is already gone.
To keep a resource, keep it in a spec. A policy may be added later if a real use case appears.
Open: what removing a package does (ADR 0028). *Patched files are never touched* (the edit stays;
mdot just stops enforcing it).

Deleting a symlink is always safe, because the content is in the repo. Deleting a rendered copy is
safe only if live == recorded. Otherwise it's a conflict.

= Apply <apply>

`apply` refuses to run while any conflict exists. There is no `--force` for now (ADR 0016).

*Executing a clean plan* (ADR 0029). `apply` creates each link first, then records it in state
right away. It stops at the first failed write and exits with 2 (ADR 0053); the output is described
under *Apply output* (@output). Running `apply` again continues: links already made are no-ops,
and a link whose state write was lost is adopted. Directories mdot creates follow the same order;
if mdot dies between `mkdir` and recording it, the empty directory is left behind on removal.
There is no special Ctrl-C handling.

Updates and deletes also change the disk first and write state once, after their disk steps
(ADR 0033), so state may lag the disk but never leads it. A delete unlinks, then tries the recorded
`rmdir`s deepest first, then drops the record. An update unlinks the old link, makes the new one,
then updates the record; `dst` is missing for a very short moment. A `rmdir` on a directory that is
already gone counts as done; one that fails for any reason other than "not empty" is treated like
"not empty" (left, dropped from state, warned). A crash lands on an existing row: after a delete's
unlink on *forget*, after an update's unlink on *re-create* (whose "removed by hand" message is
then wrong), after an update's new link on *adopt*. Open: whether a partial apply gets a
generation.

= Output <output>

*Plan layout* (ADR 0051). `mdot plan` groups resources under each spec's name, in dependency order.
Inside a spec, resources come in the order the spec declares them. A line
is symbol, kind (padded so paths line up), `dst -> src`, and an optional detail in parentheses;
`src` and `dst` are shown as written (`~` kept). Symbols: `+` create, `~` update, `-` delete, `=`
no-op, `!` conflict (ADR 0052). A conflicting resource gets its `!` line at its own position,
directly followed by its ADR 0050 `conflict:` line on stderr, not indented. One summary line ends
the run, leaving out zero counts; with nothing to do it is `No changes.`

```
waybar
  + link  ~/.config/waybar -> config
foot
  + link  ~/.config/foot/colors.ini -> colors.ini
  ! link  ~/.config/foot/foot.ini -> foot.ini
conflict: ~/.config/foot/foot.ini: exists and is not managed
hyprshot
  - link  ~/.config/hyprshot  (spec removed)

Plan: 2 to create, 1 to delete, 1 conflict.
```

`-v` / `--verbose` takes an optional level attached with `=` (`-v=2`); plain `-v` is 1. Level 0
(default) shows changes and conflicts only; a spec's heading appears only when it has a line to
show. Level 1 adds no-ops as `=` lines. Level 2 also shows what is desired, recorded and live for
each resource. Higher levels act like 2. Errors and warnings show at every level. `-v 2` is level 1
with a spec path `2`. Open: the form of the level-2 lines, colors for the symbols, and the wording
of details per kind.

*Apply output* (ADR 0052). `apply` uses the same layout, order, headings and `-v` levels. Each step
line is printed once, after its step finishes. A failed step gets `!` and its `error:` line right
under it; the error says what was attempted (`could not create link: ...`). Steps after the failure
are not attempted and not reported. The summary goes to stdout, past tense, without counting the
failure: `Applied: 2 created, 1 updated, 1 deleted.`, `Applied: nothing.` when the first step
failed, `No changes.` when there was nothing to do. "Run `apply` again" comes later as a `hint:`
line. Open: what `apply` prints when it refuses because of conflicts, the confirmation prompt and
`--yes`, progress for slow steps.

```
waybar
  + link  ~/.config/waybar -> config
foot
  + link  ~/.config/foot/colors.ini -> colors.ini
  ! link  ~/.config/foot/foot.ini -> foot.ini
error: ~/.config/foot/foot.ini: could not create link: permission denied

Applied: 2 created.
```

*Streams and markers* (ADR 0050). The plan and `mdot.print` go to stdout; errors, conflicts and
warnings go to stderr. A diagnostic is `<word>: <message>` with the word `error`, `conflict` or
`warning`; normal output has no prefix. A message about a file starts with its path or `file:line`.
`error:` and `conflict:` are red, `warning:` yellow, only when that stream is a terminal and
`NO_COLOR` is unset or empty. Follow-up `hint:` / `note:` lines come later, near the end.

*Exit codes* (ADR 0053). 0 is success, including a plan with pending changes and a run with only
warnings. 1 means mdot refused because of a rule: a conflict, or a spec that breaks a rule. 2 is an
error: a usage error (clap's own code), an unreadable file, a Lua error while loading, or a failed
write during `apply`. When both 1 and 2 apply, the code is 2.

= State and generations (git-based) <generations>

The repo already has history in git. Generations reuse it: they record *which commit was applied*
and *what was deployed*, but they don't snapshot content.

```
$XDG_STATE_HOME/mdot/               one state directory per user (ADR 0062)
  state.json                        repo path, deployed resources, created dirs
  generations/0001.json ...         one per successful apply
  backups/<gen>/...                 originals moved aside by adopt
```

`state.json` (ADR 0060) is a version number, the repo path (ADR 0062), the directories mdot created, and a flat list of
resource records. Each record has a `kind` and that kind's fields; its ID is computed from them
(ADR 0054), not stored. A link record holds its owning `spec` (ADR 0055) and absolute `src` and
`dst`. Download fields follow ADR 0032 and are not fixed yet. There is no removal policy to store
(ADR 0061).

```json
{ "version": 1,
  "repo": "/home/nexus/dotfiles",
  "created_dirs": ["/home/nexus/.config/foo"],
  "resources": [
    { "kind": "link", "spec": "foo",
      "src": "/home/nexus/dotfiles/specs/foo/foo.conf",
      "dst": "/home/nexus/.config/foo/foo.conf" } ] }
```

Loading: a missing file is empty state. A file that doesn't parse, has no `version`, holds two
records with one ID, or a `kind` this mdot doesn't know is an error (exit 2). A newer `version`
than mdot knows is refused with "upgrade mdot" (exit 2). An older one is migrated in memory and
saved as the current version on the next write; each version bump ships a migration from the one
before.

*The repo path* (ADR 0062). mdot supports one repo per user; moving or renaming it is not
supported. The `repo` field holds the repo path, absolute and lexically normalized (ADR 0056). When it
is missing (or there is no state), the current path is stored without a prompt. When it differs from
the current repo, `plan` and `apply` first print a `warning:` naming both paths on stderr, then ask
`continue? [y/N]`; no stops, yes plans normally. `--yes` does not answer it. With no terminal on
stdin, mdot refuses (exit 1). A successful `apply` stores the new path. To try another repo without
touching the real setup, point `XDG_STATE_HOME` elsewhere. _Open: the state directory on macOS and
Windows._

*Locking* (ADR 0063). Runs lock `$XDG_STATE_HOME/mdot/lock` with an OS file lock, which the kernel
releases when the process exits, even on a crash. `plan` and `status` take a shared lock; `apply`
takes an exclusive one. The lock is taken before `state.json` is read and held until the run exits,
including while `apply` waits for its confirmation. A run that cannot get the lock prints
`error: another mdot run is using <state dir>; try again when it finishes` and exits 1. `specs`,
`--help` and `--version` don't lock. The state directory and lock file are created if missing, and
the lock file is never deleted. Later commands that write state (`adopt`, `rollback`) lock
exclusively; read-only ones (`generations`) share.

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

= System scope <system-scope>

- `sysfile()` (parked, ADR 0014) targets deploy as *root-owned copies with explicit
  `owner`/`group`/`mode`, never symlinks*. A root-read config that points into a user-writable repo
  would be a privilege-escalation path.
- `render()` may target system locations. The result is still a copy.
- Privileged steps are collected into one batch. mdot writes the batch to a temp file and runs
  `sudo mdot --exec-plan <file>`, so there's one prompt per apply. The privileged side re-validates
  the batch and only executes resources marked `system`.

Systemd units, groups and users are deferred (@roadmap).

= Packages <packages>

Phase 5. _May change: ADR 0028 (Proposed) says this section is outdated._

The package provider interface is defined in phase 1 so the resource model accounts for it, and
implemented in phase 5:

```rust
struct PackageInfo { installed: bool, version: String, reason: Reason }
enum Reason { Explicit, Dependency }

trait PackageProvider {
    fn query(&self, name: &str) -> Result<PackageInfo, Error>;
    fn install(&mut self, names: &[String], reason: Reason) -> Result<(), Error>;
    fn remove(&mut self, names: &[String]) -> Result<(), Error>;
    fn set_reason(&mut self, names: &[String], reason: Reason) -> Result<(), Error>;
    fn list_explicit(&self) -> Result<Vec<String>, Error>;
}
```

Package semantics:

- A spec's `package` clause (ADR 0021) installs the package as *explicit*.
- A package reached only through `depends` is installed as a *dependency* (`--asdeps`). It becomes
  removable once nothing references it, using the provider's own orphan tracking (`pacman -Qdtq`).

= CLI

#table(
  columns: (auto, 1fr),
  [Command], [Purpose],
  [`mdot plan [--diff]`], [show what apply would do (@output)],
  [`mdot apply [--yes]`], [execute the plan, write state and a generation (@apply)],
  [`mdot status`], [resource drift, read-only (ADR 0031)],
  [`mdot verify [--all]`],
  [hash downloads that `plan` reported as conflicts (all with `--all`) and refresh their recorded
    stat; never changes `dst` (@net-download)],
  [`mdot adopt <path> [--name N]`],
  [move an existing target into its mirror slot, symlink it back, and write `specs/<N>.lua` if no
    spec owns that path. _Open: what it writes now that a spec is a directory, `specs/<name>/`
    (ADR 0014)._],
  [`mdot generations`], [list generations],
  [`mdot rollback [N]`], [plan and apply an older generation],
  [`mdot query <file> <q> ...`], [standalone tree-sitter query/edit (@tree-sitter)],
  [`mdot specs`], [list the specs the current host reaches, in dependency order (debugging)],
)

Global flags: `--repo <dir>`, `-v`/`-q`, `--color`. _Open: `-q` and `--color` have no ADR; ADR
0050 decides color from the terminal and `NO_COLOR`._

= Architecture <architecture>

```
src/
  lua/       loader: config.lua + specs/** -> SpecSet; sandboxed per-file environment table; clause constructors
  model/     Spec, Host/OS context, Resource variants
  graph/     depends DAG from hosts/<host>.lua, topo sort, cycle reporting
  ts/        tree-sitter query + edit engine, grammar registry
  planner/   desired x recorded x live -> Plan; pretty printer
  executor/  apply Plan; privileged batch via sudo re-exec
  state/     state.json, generations, backups (atomic writes)
  vcs/       git shell-out: rev-parse, worktree
  platform/  XDG resolution, os-release, PackageProvider interface
  bin/       clap command wiring (mdot.rs)
tests/       cargo integration tests + fixture repos for end-to-end plan/apply
```

= Roadmap <roadmap>

The core config manager comes first. Package handling and the other extras come later.

#table(
  columns: (auto, 1fr),
  [Phase], [Scope],
  [0],
  [Research experiments S1–S6 (`research.typ`, Methodology). Their results may change this spec
    before Phase 1 is locked],
  [1],
  [Skeleton (Cargo + CI build, ADR 0036). Lua loader + sandbox, `spec {}` clause
    tables, `hosts/` + `depends` selection, `file.link()`, `dst` conflict checks, state file, `plan` /
    `apply` / `status` / `specs`. User scope only],
  [2], [`adopt`, generations + `rollback` via git worktree, backups],
  [3], [System scope: `sysfile`, sudo batch executor (on hold, ADR 0014)],
  [4], [Tree-sitter engine: `mdot query`, then `render()` and `patch()`],
  [5], [Package providers: pacman, the `package` clause, explicit/dep install reasons],
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
