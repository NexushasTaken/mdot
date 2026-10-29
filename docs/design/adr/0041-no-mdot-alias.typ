#import "../template.typ": adr

#adr(number: 41, title: [`mdot` has no built-in alias], status: [Accepted], date: [2026-10-25])[
= Context
ADR 0038 puts everything mdot hands to Lua in one global table, `mdot`, and left open a shorter
name or alias for it. ADR 0038, 0039 and 0040 make parts of that table read-only or checked against
a schema.

= Options
- *Keep `mdot` only.*
- *Add a built-in short alias* such as `M`, `m` or `md`. `M` is the usual name of a Lua module
  table (`local M = {} … return M`), so it would be shadowed often; `m` and `md` are easy to shadow
  with ordinary locals; and two names for one table means the docs and error messages pick one
  while specs may use either.

= Decision
From the author:

- *Keep `mdot` as the only name; there is no built-in alias.*

Claude's argument, which the author agreed with: Lua gives an alias for free. Any file can write
`local v = mdot.vars` and use `v.cursor.size`; a local refers to the same table.

Accepted additions proposed by Claude:

- *An alias behaves the same as the full name.* Reading or writing through a local
  (`local v = mdot.vars`) gets the same checks as through `mdot`: a spec writing `v.font = …` is an
  error, and a host file writing `v.cursor.size = "x"` fails the schema check.
- *`design.typ` shows `local v = mdot.vars`* as the way to get a shorter name.

= Consequences
- Closes ADR 0038's open item on a shorter name or alias. ADR 0038 itself is unchanged.
- The read-only and schema checks of ADR 0038, 0039 and 0040 must hold for every reference to the
  table, not only for the name `mdot`.
]
