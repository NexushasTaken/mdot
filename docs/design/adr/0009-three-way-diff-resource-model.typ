#import "../template.typ": adr

#adr(number: 9, title: [Resource model with a 3-way diff], status: [Accepted], date: [2026-10-06, confirmed 2026-10-23])[
= Context
The author wants plan/diff, status/drift and adopt, and asked how a diff can work when configs are
symlinks (a symlinked file's content always equals the repo).

Proposed on 2026-10-06 with a generic seven-row table for every kind. Confirmed on 2026-10-23, after
links (ADR 0030) and downloads (ADR 0024, ADR 0026) had each needed rules the generic table did not
have. The link/git ownership part was decided separately in ADR 0031.

= Options
- One generic table that every kind follows.
- A table per kind, all in the same desired × recorded × live form. Chosen.

= Decision
Specs compile into resources (`Link`, `Render`, `Patch`, `Download`, `SysFile`, later `Package`).
The planner compares *desired* (specs) × *recorded* (state) × *live* (system) per resource and
emits an action per resource (create, adopt, update, noop, delete, forget, conflict).

- *Every kind gets its own table* in desired × recorded × live form. The generic table in
  `design.typ` is the common pattern; a kind's own table governs.
- *Each kind must define four things* before it has a table:
  + its *identity*
  + what *live* observes, and how expensive that is
  + what *matches* means
  + what is *recorded* in state

For `Link`, see ADR 0030 (table) and ADR 0031 (mdot does not track linked content). For `Download`,
see ADR 0032.

= Consequences
- Removal and drift detection become possible because recorded state exists.
- A new kind slots into the planner, state and `status` once it answers the four definitions.
- Whether users understand what is and is not reported is RQ3.

= Open
- Kinds with no observable result (for example running a command or a hook) have no live column, so
  they do not fit this model. To be decided in a separate ADR.
- The tables for `SysFile`, `Render`, `Patch` and `Package`.
]
