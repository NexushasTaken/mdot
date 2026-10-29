#import "../template.typ": adr

#adr(number: 18, title: [`spec { ... }` collects declarative clauses], status: [Accepted], date: [2026-10-10])[
= Context
ADR 0015 showed clauses inside `spec { ... }` but did not say whether a clause acts when it is
called. Bare top-level calls (`link(...)` on its own line) would run in file order and could act as
side effects while the file loads.

= Options
- Clauses as statements that act or register themselves when called.
- `spec.lua` returns a bare table of clauses.
- `spec.lua` returns `spec { ... }`, a wrapper call receiving the table of clauses.

= Decision
`spec.lua` is `return spec { link(...), link(...), ... }`. A clause call only builds and returns a
value; it does no work. `spec` collects the table and returns it, and mdot reads it after the file has
run and decides what to do and when (validation, planning, ordering, execution). The wrapper tags the
table as a spec, so a `spec.lua` that returns anything else is an error, and so is an empty `spec {}`.
Argument expressions such as `host.name == "nexos"` are ordinary Lua evaluated at load time, so
`enabled(bool)` (ADR 0017) is unchanged.

*Nesting.* An entry in `spec { ... }` may also be a list of clauses, for example the result of a
helper function that loops over file names. mdot flattens such lists, depth first and in order, before
it reads the clauses. Anything in the table that is neither a clause nor a list of clauses is an
error, and the message names the position, e.g. "entry 1, item 2 is not a clause".

= Consequences
- Loading is pure: a spec cannot cause effects, which supports ADR 0013.
- mdot can inspect all clauses before acting: check every `src`, report every conflict (ADR 0016),
  and later order clauses across specs without relying on file order.
- Clause order inside the table is kept for error messages, but has no meaning for the result.
- Nested lists are flattened, so a helper may return several clauses (see the decision above).
]
