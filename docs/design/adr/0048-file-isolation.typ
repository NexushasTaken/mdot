#import "../template.typ": adr

#adr(number: 48, title: [Every file gets a fresh environment; shared library tables are read-only], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0013 left open whether each loaded file gets a fresh environment, and how to stop one spec from
changing a shared table such as `string` that every other spec sees. `design.typ` already said each
spec runs in a "fresh environment table", but that was never decided. ADR 0046 assumes isolation
between spec files.

In one Lua state, `string` is a single table. A fresh environment holds a reference to it, not a
copy, so `string.upper = nil` in one file removes `upper` for every file loaded after it, including
method calls such as `("x"):upper()`: the string metatable's `__index` is the same table. Checked
in Lua 5.5 and with mlua 0.10.5 (`lua54`).

The rules for the `mdot` table are already set per kind of file: `mdot.vars` (ADR 0038),
`mdot.opt` (ADR 0045), `mdot.os` and `mdot.dirs` (ADR 0040, 0043, 0044), and unknown members
(ADR 0046).

= Options
- *Globals:* a fresh environment per file, or one global space shared by all files.
- *Shared library tables:*
  - A. Mutable; a file that changes one is the user's fault.
  - B. Read-only; writing to one is an error.
  - C. A separate copy per file. A copy of `string` does not change the string metatable, so
    `("x"):upper()` would still use the original.
- *`config.lua` and host files:* the same rules as specs, or a "prelude" that may patch libraries or
  define globals that later files see.

= Decision
From the author:

- *Each file has its own globals,* and mdot decides which globals are shared.
- *Option B:* the shared library tables are read-only.

Claude's recommendation, which the author adopted without giving a reason of their own:

- *The same rules for every file.* `config.lua`, host files and specs each start from a fresh
  environment that holds only what mdot puts in it, and the library tables are read-only in all of
  them. Claude's reasons: one rule to remember; a prelude would become a hidden way to share helpers
  and decide the `require` question without saying so; one mechanism to build.

The whole rule: every file runs in its own fresh environment. Everything mdot puts in it is
read-only, except that `config.lua` and the host file may write `mdot.vars` and `mdot.opt` under
ADR 0038 and 0045.

Accepted additions proposed by Claude:

- *Error message:* writing to a read-only library table is an error naming the file, the line and
  the key (`a/spec.lua:1: cannot set string.upper`).
- *String methods are covered:* `getmetatable("")` returns a locked marker, not the real string
  metatable, so a file cannot reach the real `string` table through a string.
- *`design.typ`* states the rule in its loading steps and sandbox paragraph.
- *Known quirk, documented:* `next(string)` is `nil` and `#math` is `0`; `pairs(string)` works.

= Consequences
- Load order cannot change what a file sees: a global or a library change in one file never
  reaches another.
- A mistake shows up as an error in the file that made it, not in a later file.
- Until `require` is decided, files cannot share helper functions.
- Implementation notes from the 2026-10-26 test with mlua 0.10.5 (`lua54`):
  - mlua's `Table::set_readonly` and `Lua::sandbox` exist only for Luau, so mdot builds read-only
    tables itself with metatables (an empty proxy whose `__index` is the real table and whose
    `__newindex` raises an error, plus `__pairs` and a `__metatable` lock). Each file's environment
    is set per loaded chunk.
  - The error names the file only if the write check raises it at the caller's level. A check
    written as a Rust function gave `cannot set string.upper` with no location. A write made inside
    a C function, such as `table.insert(string, 1)`, has no location either.
  - `pcall` can catch the error, but the table is unchanged.
  - `next` and `#` read the proxy directly, which is why the quirk above exists.

= Open
- *`require`:* whether and how files share helper modules (ADR 0013's open item).
]
