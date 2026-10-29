#import "../template.typ": adr

#adr(number: 15, title: [`link(src, dst)` with plain paths, `spec.lua` is absolute], status: [Accepted], date: [2026-10-10])[
= Context
ADR 0014 left the explicit `spec.lua` vocabulary open. A whole-directory link would also link
`spec.lua` into the target. Options for directories were per-file links, a subfolder for the files,
or an automatic per-file mode (the old `walk`).

= Decision
The only deployment clause is `link(src, dst)`. `src` is relative to the spec directory, `dst` is a
plain string with a leading `~` expanded. Files and directories are handled the same way. For
directory targets the recommended layout is a `config/` subfolder. `spec.lua` has full control and
mdot never excludes anything on its own, so `link(".", dst)` is valid and links `spec.lua` too. A
missing `src` is an error at load time.

= Consequences
- No `walk`, `from` or `dirs` is needed for this layout. Per-file linking can be added later if a
  real need shows up.
- Authors can leak `spec.lua` into a target; that is accepted as the cost of an absolute `spec.lua`.
- Open: `$XDG_CONFIG_HOME` and other variables in `dst`; what a link does when `dst` already exists
  (the first-run table in `design.typ` still applies and needs a rewrite).
]
