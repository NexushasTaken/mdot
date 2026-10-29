#import "../template.typ": adr

#adr(number: 35, title: [A generic planner: classify each ID, then the kind decides], status: [Accepted], date: [2026-10-24])[
= Context
ADR 0009 gives every kind its own desired × recorded × live table, and ADR 0034 matches desired and
recorded resources by ID. The tables for links (ADR 0030) and downloads (ADR 0032) have the same
shape: each side is either absent or a value, and the outcome depends on which values match. Only
what a value is, and what "matches" means, differs per kind.

The author sketched a generic reconcile in Lua (`reconcilation.lua`, a toy with a person's name and
age) to test whether the model can be abstracted: one algorithm that only knows it has three pieces
of data, and per-kind helpers that know how to read and compare them.

Counting the cases for links showed that the number of live states depends on the row: with one
`src` value in play live is absent, that value, or anything else (3); with two different values it is
absent, either value, or anything else (4). Together with the three desired/recorded pairs this gives
13 cases, which ADR 0030 writes as 11 rows.

= Options
- *One reconcile function that also decides the outcomes* (the author's first sketch). Every kind
  would share one table, but ADR 0009 says a kind's own table governs, and links already differ from
  the generic table in three rows (re-create, forget, adopt when live matches the new desired value).
- *A generic classify step, with the outcome decided by each kind.*

= Decision
From the author:
- *The 3-way model is abstracted.* The algorithm knows nothing about the data. Each kind supplies
  the helpers that read and compare it; the helpers are the interface (the strategy pattern).
- *It is written as if it were a library unrelated to mdot.* Whether it becomes a separate library
  or a module inside mdot is open.
- *Resources are matched by ID first* (ADR 0034).
- The author implements it in C++.

Accepted additions:
- *Classify returns a case, never an action.* The case says whether desired and recorded exist,
  whether they match, and what live matches. It is the same for every kind.
- *Each kind decides.* A kind maps a case to an action with its own table, and falls back to the
  generic table in `design.typ` for the rows it does not override.
- *The plan is data.* Planning returns a list of steps and changes nothing; `apply` runs the steps
  later (ADR 0029, ADR 0033). This keeps `plan` and `--dry-run` free of side effects.
- *Live states have names:* `absent`, `desired`, `recorded`, `both` (live matches both, possible only
  when desired and recorded match), `other`.
- *IDs are sorted* before planning, so the same input gives the same plan output.

The algorithm, in pseudocode, is in `docs/design/planner.typ`.

= Consequences
- Each kind provides: its ID, how to observe live, what "matches" means, and optionally its own
  decide table.
- Classify and each decide table are pure functions, so every row of a kind's table can be tested
  without touching the filesystem.
- The pseudocode in `planner.typ` gives the right result for all 13 link cases of ADR 0030 (checked
  by running it).

= Open
- *Separate library or a module inside mdot* with no mdot includes.
- *C++ shape:* a `virtual` interface or `std::variant`. The author decides while implementing.
- *Cases a kind's table does not list:* whether they default to conflict.
- *Is "same / differ" enough?* Downloads (ADR 0032) tell "only `mode` differs" (`chmod`) apart from
  "`R ≠ D`" (download again). Either decide also gets the values, or the kind's comparison returns
  more than yes/no.
- *"Matches" compares different shapes.* Live is an observation (`lstat` + `readlink`, or a stat),
  recorded is a state record, desired is a clause. For downloads, live can only be compared with the
  record, since `plan` never hashes. How the comparison is typed is open.
]
