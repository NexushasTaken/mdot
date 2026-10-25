#import "../template.typ": adr

#adr(number: 46, title: [No `mdot.g`; unknown `mdot` members are errors], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0038 named `mdot.g`, after Neovim's `vim.g`, as a member of `mdot` and left it undesigned. In
Neovim, `vim.g` holds global variables that any file can read and write, with no base, schema or
load order. ADR 0038 rejected "every file writes, like `vim.g`" for `mdot.vars`, and gave
`mdot.vars` a base and a schema (ADR 0039) for the clean filter.

= Options
- *Add `mdot.g`* as in Neovim.
- *Do not add it.*

= Decision
From the author:

- *There is no `mdot.g`.* The author's reason: it is almost the same as `mdot.vars`.

Claude's argument, which the author agreed with: the only thing `mdot.g` would add is specs writing
values that other specs read, which is ADR 0038's rejected option A (two specs setting the same key
silently fight by load order, and it undoes the isolation between spec files of ADR 0013).

Accepted additions proposed by Claude:

- *Unknown members are errors:* reading or writing `mdot.g`, or any other member `mdot` does not
  have, is an error naming it. `mdot.g.x = 1` does not create a table.

= Consequences
- Closes the `mdot.g` part of ADR 0038's open item. ADR 0038 is unchanged.
- `mdot` has exactly the members designed so far: `os`, `dirs`, `vars` and `opt`.
- `mdot.env` stays open in ADR 0038.
]
