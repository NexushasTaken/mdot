#import "template.typ": *

#show: spec.with(
  title: "mdot — Open design",
  meta: [Draft · 2026-10-29 · Companion to `design.typ`],
)

= About this document

This file holds the parts of mdot's design that are *not settled yet*: features that are not
designed, only partly designed, parked or outdated, and the open lines taken out of settled
sections. The settled spec is `design.typ`; section names here match its sections.

When an open item is decided, move it to `design.typ`. The checklist of open decisions is
`adr/todo.typ`.

= Stack

#table(
  columns: 2,
  [Concern], [Choice],
  [Structural editing], [tree-sitter (+ vendored grammars); Rust binding open (ADR 0036)],
)

= Lua API

== Clauses

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

*Open* (ADR 0038, 0045): `mdot.env`, which would replace part of ADR 0013; on hold until a real
spec needs it. The marker filter default's "Set by" class (ADR 0037).

= Resource kinds

== `net.download()` — pinned downloads

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
  philosophy rule 2 (`design.typ`, Philosophy).

The same engine powers the standalone CLI:

```
mdot query <file> '<query>' [--lang L] [--set VALUE] [--capture NAME] [--in-place]
```

Initial grammars: json, toml, ini, css, yaml, lua. Grammars are vendored and compiled in. The final
set depends on experiment S1 (`research.typ`, Methodology).

= Resource model, plan and diff

== Resources

The rows for kinds that are not designed yet (the settled rows are in `design.typ`):

#table(
  columns: 4,
  [Kind], [Identity], [Desired], [Observed (live)],
  [`Render`], [kind + target path], [output hash + bytes], [file hash],
  [`Patch`], [kind + target path + query], [the edits],
  [does the query on the live file already yield the desired values?],
  [`SysFile`], [kind + target path], [bytes hash, owner, mode], [hash, owner, mode],
  [`Package` _(phase 5)_], [kind + package name], [installed, reason explicit/dep], [provider query],
)

Kinds with no observable result, such as running a command, do not fit this model;
that is open.

== Removal

Open: what removing a package does (ADR 0028). *Patched files are never touched* (the edit stays;
mdot just stops enforcing it).

Deleting a rendered copy is safe only if live == recorded. Otherwise it's a conflict.

= Apply

Open: whether a partial apply gets a generation.

= Output

- Open: the form of the level-2 lines, colors for the symbols, and the wording of details per kind.
- *Apply output:* "Run `apply` again" comes later as a `hint:` line. Open: progress for slow steps.
- *Streams and markers:* follow-up `hint:` / `note:` lines come later, near the end.

= State and generations (git-based)

The repo already has history in git. Generations reuse it: they record *which commit was applied*
and *what was deployed*, but they don't snapshot content.

The state directory's entries for generations and backups:

```
<state dir>/
  generations/0001.json ...         one per successful apply
  backups/<gen>/...                 originals moved aside by adopt
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

= System scope <system-scope>

- `sysfile()` (parked, ADR 0014) targets deploy as *root-owned copies with explicit
  `owner`/`group`/`mode`, never symlinks*. A root-read config that points into a user-writable repo
  would be a privilege-escalation path.
- `render()` may target system locations. The result is still a copy.
- Privileged steps are collected into one batch. mdot writes the batch to a temp file and runs
  `sudo mdot --exec-plan <file>`, so there's one prompt per apply. The privileged side re-validates
  the batch and only executes resources marked `system`.

Systemd units, groups and users are deferred (`design.typ`, Roadmap).

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
  [`mdot adopt <path> [--name N]`],
  [move an existing target into its mirror slot, symlink it back, and write `specs/<N>.lua` if no
    spec owns that path. _Open: what it writes now that a spec is a directory, `specs/<name>/`
    (ADR 0014)._],
  [`mdot generations`], [list generations],
  [`mdot rollback [N]`], [plan and apply an older generation],
  [`mdot query <file> <q> ...`], [standalone tree-sitter query/edit (@tree-sitter)],
)

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
