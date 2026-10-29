#import "../template.typ": adr

#adr(number: 49, title: [No `require` for now; `mdot.vars` holds only data], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0013 leaves `package`/`require` unreachable and left open whether specs can share helper
modules, and from where. ADR 0048 gives every file its own fresh environment with read-only library
tables, so no file can share code with another. ADR 0042 notes that splitting a large `config.lua`
depends on this question. ADR 0019 resolves `depends` names from `<repo>/specs/`, never relative to
the caller.

The author has no concrete case yet: no helper they know they would share between specs, and no
file they need to split.

A function stored in `mdot.vars` would also share code between files. It carries its upvalues from
`config.lua`, so state it captures (a counter, say) is shared by every spec that calls it, and the
result depends on load order. ADR 0048's read-only tables do not reach upvalues.

= Options
- *A. Not now.* No `require`; helpers stay in the file that uses them.
- *B. A repo-wide `lib/`.* `require("x")` loads `<repo>/lib/x.lua` only, resolved from the repo
  root like `depends` (ADR 0019).
- *C. Caller-relative.* `require("x")` loads `x.lua` next to the calling file.

= Decision
From the author:

- *Option A.* There is no `require` for now.
- *`mdot.vars` holds only base values,* not functions. The author first gave "a helper can be a
  function in `mdot.vars`" as the reason for A, then withdrew it after the problems above.

Claude's arguments for A, which the author agreed with but did not give as reasons: adding
`require` later does not break existing specs, while changing or removing it does; and no real
case needs it yet.

Accepted additions proposed by Claude:

- *A function in base `mdot.vars` is a schema error* naming the key path, like the other ADR 0039
  errors.
- *`require` stays unreachable* as in ADR 0013. Calling it gives Lua's ordinary "attempt to call a
  nil value" error; there is no special message.
- *When to revisit:* when the same helper is copied into a second file, or when `config.lua` becomes
  painful to keep as one file.
- *`design.typ`* records this in place of its open `require` item.

= Consequences
- Closes ADR 0013's open `require` item for now. ADR 0013 is unchanged.
- Helpers are duplicated across files until the revisit.
- `config.lua` stays one file (ADR 0042's note).
- Adds function values to the errors of ADR 0039's schema.

= Open
- If `require` comes back: where it looks (B, C or both), and how a module behaves under ADR 0048
  (which environment it runs in, whether it runs once or per caller, whether its result is
  read-only).
]
