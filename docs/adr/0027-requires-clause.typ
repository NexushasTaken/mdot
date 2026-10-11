#import "../template.typ": adr

#adr(number: 27, title: [`requires` declares raw packages; `depends` names specs only], status: [Accepted (explicit install, unknown-key and ordering rules: Proposed)], date: [2026-10-11])[
= Context
ADR 0021 added the `package` clause: a spec states the one package its config is for. It did not
say how a spec expresses "I need this tool installed" when no spec exists for the tool. The earlier
mdot design handled it by fallback: `depends("ripgrep")` meant the spec `ripgrep` if one existed,
and otherwise the package `ripgrep`.

The author also wants mdot to record which packages are installed, why, and which config uses them.
About 30 packages in `~/dotfiles-v2` have no config at all, so one directory plus one `spec.lua`
for each would be mostly boilerplate.

= Options
- Keep the fallback in `depends`. A typo (`rgprep`) silently becomes "install a package called
  rgprep". Adding `specs/ripgrep/` later silently changes what the same line means, which is
  resolution by precedence. Also wrong in meaning: `depends("nvim")` pulls in a config, while the
  need is only a binary.
- Make one package-only spec per package. Clear graph, but heavy for 30 packages.
- Allow several `package()` calls in one spec. Breaks the rule that a spec owns at most one
  package, and "needed by `utils`" says nothing about the real consumer.
- A separate clause, `requires`, for raw packages. Chosen.

= Decision
*Two namespaces, three clauses.*

#table(
  columns: (auto, auto, auto, 1fr),
  [Clause], [Target], [Limit], [Meaning],
  [`package(name?, opts?)`], [one package], [at most one per spec], [The spec is the config _for_ this package (ADR 0021).],
  [`depends(...)`], [specs only], [many], [Apply those specs too. An unknown name is a hard error. There is no fallback to a package.],
  [`requires { ... }`], [raw packages], [many], [Make sure these are installed. The spec does not own them.],
)

*Shape of `requires`.* A mixed Lua table:

```lua
requires {
  "git", "curl",                                  -- array entry: name only
  ripgrep = "telescope live_grep",                -- name = string: the why
  fd      = { why = "telescope find_files", alt = <TBD> },  -- name = table: options
  bat     = { alt = <TBD> },                      -- why is optional
}
package("neovim", { why = "...", alt = <TBD> })   -- package takes the same options
```

- The form decides the meaning: an array string is a package name with no options; `name = "text"`
  is shorthand for `{ why = "text" }`; `name = { ... }` is the full options table.
- `why` is optional and is free text. mdot does not parse it. It is shown by listing commands.
- `alt` is accepted by both `requires` entries and `package`. Its value is *not decided*. The loader
  stores it and does not validate it. Until the Phase 5 design, using `alt` is a "not implemented
  yet" error, so no spec can depend on a shape that may change.
- Naming the same package twice in one `requires` table (`{ "git", git = "..." }`) is an error.

*Ownership and sharing.*
- Two reachable specs that both call `package("x")` is an error that names both specs, like the
  same-`dst` rule (ADR 0021). A package has one owner.
- A spec may `requires("x")` while another spec owns `x`. That is an extra edge, not a conflict.
- Several specs may `requires("x")`. Each keeps its own `why`.

*The installed set* is every `package()` and `requires` entry in the reachable specs, de-duplicated
by package name. A package that no reachable spec mentions any more is handled by the removal
policy for `package` (ADR 0011).

*Reverse index.* The graph answers "why is this installed" and "which config uses it". A future
`mdot why <package>` prints, for example, `ripgrep <- required by nvim (telescope live_grep)`, and
for an owned package, `neovim <- owned by nvim`.

*Install reason.* Proposed: every package in the installed set is installed as _explicit_. This
settles the open item in ADR 0021. Installing reachable packages `--asdeps` is wrong for mdot: no
pacman package depends on them, so `pacman -Qdtq` lists them as orphans and a routine
`pacman -Rns $(pacman -Qdtq)` would remove packages mdot is supposed to keep. mdot's own state
decides what is removable.

*Loader rules* (Proposed).
- An unknown key in an options table is an error, so a misspelled `why` is never dropped silently.
- Entries are sorted by package name before planning. Lua's `pairs` order is undefined for the
  key-value part of a table; sorting keeps `plan` output and recorded state stable.

= Consequences
- Updates ADR 0021: adds `requires`, closes its open install-reason item, and fixes `opts` to
  `why` and `alt`. ADR 0021 is kept unchanged as history.
- Package-only specs are no longer the main way to install a bare tool. They are a grouping choice:
  a spec such as `utils` or `fonts` holds `requires` lines, and a one-package spec exists only when
  something needs a name to `depends` on.
- The earlier idea of a single-file spec (`specs/<name>.lua`) is dropped for now. Reconsider it only
  if grouping specs feel heavy in practice.
- Phase 5, not Phase 1. The loader must accept the clause shapes (including `alt` as an opaque
  value) so the grammar does not change later. The `PackageProvider` interface loses `Reason` and
  `set_reason`; `install` takes names only.
- Open for Phase 5: the value of `alt` and how it resolves against the platform; whether the
  per-platform `pkg_alts` wording from ADR 0021 is replaced by `alt`; whether `why` should ever be
  required.
- `design.typ` is not changed by this ADR. Its package section (the `package` row, the
  explicit/dependency semantics and the provider interface) still follows ADR 0021 and needs a
  separate update.
]
