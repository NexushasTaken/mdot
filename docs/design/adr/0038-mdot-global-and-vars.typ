#import "../template.typ": adr

#adr(number: 38, title: [A global `mdot` table; `config.lua` defines `mdot.vars`, hosts only override], status: [Accepted], date: [2026-10-25])[
= Context
Markers (ADR 0037) give `vars` its first real consumer: the author's Yolk values (git name and
email, font, cursor name and size) differ per machine. ADR 0037 stores each marker's canonical
value, "the marker evaluated with the base `vars`", and left open what base `vars` means once
per-host values exist. `design.typ` said `config.lua` returns `{ vars = {...} }` and that `vars` is
not designed yet. ADR 0019 makes the host file the root of a machine. ADR 0013 makes loading pure
and leaves open how to stop one spec from changing a table every other spec sees.

= Options
- *Who writes the values:*
  - A. Every file, like Neovim's `vim.g` (`config.lua`, host files, specs).
  - B. Layers: `config.lua` sets the base, the host file overrides, specs only read.
  - C. Nobody mutates: each file returns a table and mdot deep-merges them.
- *New keys in a host file:* allow them, or allow only overriding keys `config.lua` defined.

= Decision
From the author:

- *One global `mdot` table, in the style of Neovim's `vim`.* Values live in `mdot.vars`. The
  author's reason: copy how Neovim configs work.
- *Option B.* `config.lua` is the only place that defines vars. The host file can only override
  them, and specs can only read them.
- *A host cannot add keys.* The author first chose to allow new keys, then reversed it. A marker
  that uses a key only a host defines would have no base value, so the git clean filter
  (ADR 0037) could not compute its canonical value.

Claude's arguments for B, which the author agreed with but did not give as reasons: the base is
the state after one file, so every host agrees on it; and read-only specs remove the load-order
problem that A has (two specs setting `font` silently fight).

Accepted additions proposed by Claude:

- *Read-only is enforced:* a spec that writes to `mdot.vars` is an error naming the spec.
- *`config.lua` assigns into `mdot.vars`,* the same way the host file does. This replaces
  `design.typ`'s "returns `{ vars = {...} }`".
- *Override-only is checked:* after the host file runs, `mdot.vars` must have exactly the keys the
  base had. A new key (such as a typo, `mdot.vars.cusor`) or a missing key (assigning
  `mdot.vars.cursor = { size = 24 }` drops `cursor.name`) is an error naming the key. Assigning a
  leaf (`mdot.vars.cursor.size = 24`) overrides only that key.
- *Base `vars` is `mdot.vars` after `config.lua` alone.* This closes that open item of ADR 0037: it
  is what the clean filter evaluates markers with.
- *Without `config.lua`,* base `vars` is empty, so a host has nothing to override.

= Open
- Whether a host override may change a value's type (a number to a string).
- Spec-declared defaults, as parked in ADR 0019 (`config {}`, defaults declared by the spec and
  overridden by the host). The set of vars would then depend on which specs the host reaches, so
  there would be no single base, and a spec reading a var while loading might run before the spec
  that declares it.
- Other members of `mdot`, named by the author but not designed: `mdot.os`, `mdot.dirs` (XDG or
  Windows known folders), `mdot.opt` or `mdot.o` (configuring mdot itself), `mdot.g`. Each is
  designed when a real spec needs it.
- `mdot.env`: reading the environment conflicts with ADR 0013, which dropped `env()`. It needs its
  own decision that supersedes that part.
- A shorter name or alias for `mdot`.
- Whether the existing context value `host` becomes a member of `mdot`.

= Consequences
- Replaces the `config.lua` loading step in `design.typ`.
- Answers part of ADR 0013's open "Host and OS info": mdot hands specs values through `mdot`.
- Per-machine values live only in host files, so other people overriding the author's values
  hits ADR 0019's open question about untracked host files.
- Every value a marker can use exists in base, so the clean filter can always evaluate it.
]
