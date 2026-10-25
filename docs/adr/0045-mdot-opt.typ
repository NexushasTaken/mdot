#import "../template.typ": adr

#adr(number: 45, title: [`mdot.opt` holds mdot's own settings; each option says who may set it], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0038 named `mdot.opt` or `mdot.o` (configuring mdot itself, as Neovim's `vim.opt`/`vim.o`) as a
member of `mdot` and left it undesigned. ADR 0041 kept `mdot` without a built-in alias, partly
because short names are easy to shadow and two names for one table split the docs.

ADR 0011 and `design.typ` say "`config.lua`'s `defaults.on_remove` overrides the built-in default"
(`files = "remove"`, `package = "ask"`). That was written when `config.lua` returned a table;
since ADR 0038 it assigns into `mdot.vars`, so the removal default has no valid place. ADR 0011
records each resource's policy in state at apply time, on that machine. ADR 0037 leaves the marker
filter option's default open; a setting like that changes what is committed, which is why base
`vars` comes from `config.lua` alone (ADR 0038).

= Options
- *Name:* `mdot.opt`, `mdot.o`, or both.
- *Who sets it:* only `config.lua`; `config.lua` and host files; or every file.
- *Per option:*
  - A. Every option can be set by `config.lua` and host files; an option that changes committed
    content gets its own rule when designed.
  - B. Each option is marked "host-overridable" or "`config.lua` only".

= Decision
From the author:

- *The name is `mdot.opt`, the only one.*
- *`config.lua` and host files may set it.*
- *A host may set an option `config.lua` never set.*
- *Option B:* each option is marked "host-overridable" or "`config.lua` only".

Claude's arguments for `mdot.opt`, which the author agreed with: it matches the other members'
readable names (`vars`, `dirs`, `os`); a one-letter name is easy to misread, as ADR 0041 argued;
`local o = mdot.opt` gives a short name for free; and Neovim's two names behave differently, while
here they would be one table.

Accepted additions proposed by Claude:

- *First option:* `mdot.opt.on_remove = { files = …, package = … }`, host-overridable, with ADR
  0011's values and built-in defaults. It replaces the `defaults.on_remove` wording. A spec's own
  `on_remove` still overrides it.
- *Order:* built-in default, then `config.lua`, then the host file; the last write wins. Assigning a
  leaf (`mdot.opt.on_remove.package = "keep"`) changes only that key.
- *Unknown option:* setting an option mdot does not have (`mdot.opt.on_remov`) is an error naming
  the option and the file.
- *Bad value:* a value outside an option's allowed set (`files = "delete"`) is an error naming the
  option, the value and the file. All errors are reported in one run.
- *A `config.lua`-only option set in a host file* is an error naming the option and the host file.
- *Specs* may read `mdot.opt`; writing to it is an error naming the spec.
- *`design.typ` keeps the list of options* as a table: Option / Values / Built-in default / Set by.

= Consequences
- Closes the `mdot.opt`/`mdot.o` part of ADR 0038's open item. Gives ADR 0011's removal default a
  valid place again; ADR 0011 and ADR 0038 are unchanged.
- Each per-machine option is safe only if it does not change committed content; the "Set by"
  column is where that is decided.

= Open
- The marker filter default (ADR 0037): when designed, it gets a "Set by" class.
- Whether command-line flags (`--color`, `-v`) get matching options.
]
