#import "../template.typ": adr

#adr(number: 14, title: [One directory per spec, implicit or explicit], status: [Accepted], date: [2026-10-10])[
= Context
ADR 0004 split a spec across `specs/<n>.lua` and mirror roots (`configs/`, `home/`, `data/`,
`system/etc/`). Answering "where does this file end up?" meant combining the spec, the mirror table
and `dirs`. A single-file app like gdb still needed a spec file plus a mirrored directory.

= Options
- Keep mirror roots (ADR 0004).
- One directory per spec, always with `spec.lua`: uniform, but boilerplate for one-file apps.
- One directory per spec, `spec.lua` optional: no boilerplate for the common case.

= Decision
`specs/<name>/` is one spec; the name is the directory name. Without `spec.lua`, the directory is an
*implicit*, config-only spec linked whole to `~/.config/<name>`. With `spec.lua`, it is *explicit*:
`spec.lua` controls the directory and nothing is linked automatically. `name` defaults to the
directory name, and an empty `spec.lua` is an error. Implicit specs never own a package; package
ownership is opt-in in `spec.lua`, which reverses the `pkg = true` default of ADR 0005. System scope
is out of this layout for now.

= Consequences
- Supersedes ADR 0004. The mirror roots and `dirs` as a layout mechanism are gone, and `from` is no
  longer needed. The Lua API and deployment sections of `design.typ` still describe them and need a
  follow-up pass.
- `mdot plan` must show a link being dropped when `spec.lua` is added to an implicit directory.
- Open: the `spec.lua` vocabulary for explicit links (source, target).
- Open: how system-scope files fit when user and root files share a directory (ADR 0007 still holds
  for how they are deployed).
]
