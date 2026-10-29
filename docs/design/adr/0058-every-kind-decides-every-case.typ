#import "../template.typ": adr

#adr(number: 58, title: [Every kind's `decide` handles every case; no fallback], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0035 lets a kind's `decide` override only the rows that differ and fall back to the generic
table for the rest. It left open whether cases a kind's table does not list default to conflict.

The generic table covers every case, so no case is ever left without an action. But a kind silently
inherits every row it does not write, including destructive ones. Links write 4 of the 13 cases
(`recreate` twice, `forget`, `adopt`) and inherit 9, among them `update` and `delete`.

Example: a later package kind (ADR 0028, Proposed) records pre-existing packages too, with
`installed_by_mdot = false`. For removed / recorded the generic table says `delete`, which would
uninstall a package mdot never installed. The generic table cannot see `installed_by_mdot`.

The case in `src/planner.rs` is two enums, `DesiredStatus` (4 variants) and `LiveStatus` (5): 20
combinations, of which 13 can happen (`planner.typ`, "The 13 cases"; ADR 0057 makes match /
recorded impossible).

Checked in a toy crate: a `match` on one enum, or on a tuple of two enums, without a `_` arm is a
compile error (E0004) that names the missing pattern. A `_` arm silences it. The clippy lint
`wildcard_enum_match_arm` warns on `_` in a match on one enum, but not on `_` inside a tuple pattern
such as `(Red, _)`.

= Options
- *Fall back to the generic table* (ADR 0035 as written).
- *A: unlisted rows are a conflict at runtime.* Safe when it runs; a kind can still call the generic
  table on purpose.
- *B: no default; every kind writes every case,* and the compiler reports a forgotten one. Chosen.

For the case type:
- *One enum with exactly the 13 possible cases,* so impossible combinations cannot be written.
- *Two enums,* with an `unreachable!()` arm for each of the 7 impossible combinations. Chosen.

= Decision
From the author:
- *No silent defaults.* Every kind's `decide` handles every case explicitly, and the compiler catches
  a forgotten one. Reason: avoid unnecessary or unexpected destructive operations. (Defaulting to
  conflict was judged good for the same reason; B was chosen over it.)
- *A new kind writes its own table.* It does not have to use the generic table at all.
- *The case stays two enums,* with `unreachable!()` for the 7 impossible combinations. Reason: one
  enum with 13 variants is more confusing and less flexible.

Accepted additions:
- *No `_` arm in any `decide`.* This is a rule to keep, not something the compiler enforces: the
  clippy lint misses `_` inside tuples.
- *The generic table is no longer a fallback in code.* The table in `design.typ` stays as the
  starting pattern for a new kind's table: copy it, then change rows.
- *An impossible combination reaching `decide` is a bug* in `classify` or in a kind's comparisons,
  and panics (`unreachable!()`). This is acceptable because `decide` runs during planning, and
  planning changes nothing (ADR 0035).

The full links table, in pseudocode, is in `planner.typ`.

= Consequences
- Refines ADR 0035: "falls back to the generic table for the rows it does not override" no longer
  holds. ADR 0035 is kept as history.
- Closes ADR 0035's open item on cases a kind's table does not list.
- Each kind's `decide` is 13 rows plus 7 `unreachable!()` arms. Links and downloads share one such
  table (ADR 0057).
- A kind with inconsistent comparisons (for example `ld` true, `lr` false, `dr` match, which gives
  match / desired) stops `plan` with a panic instead of planning something.

= Open
- *How information that is not in the case reaches `decide`.* The `on_remove` policy (ADR 0011,
  open in ADR 0054) and a package's `installed_by_mdot` (ADR 0028) both change the answer for
  removed / recorded.
- How the differently shaped values are typed in Rust, and trait or enum (ADR 0035, ADR 0057).
]
