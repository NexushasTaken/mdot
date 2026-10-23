#import "../template.typ": adr

#adr(number: 32, title: [The 3-way diff for downloads], status: [Accepted], date: [2026-10-23])[
= Context
ADR 0009 gives every kind its own table in desired × recorded × live form. The download rules in
ADR 0024 and ADR 0026 were written as their own four-row table, not in that form. The author asked to
reword them into it. Doing so showed three cases without a rule: a recorded download that is missing
while still desired, a recorded download that is no longer desired and whose stat differs, and one
that is no longer desired and missing.

The four definitions (ADR 0009):
- *Identity:* `dst`.
- *Live:* `stat` of `dst` compared with the recorded `size`, `mtime_ns`, `inode` and permission
  bits. `plan` never hashes, so live can say "unchanged since mdot wrote it", never "equal".
- *Matches:* the stat matches the record. `R` is the recorded identity, `D` the desired one
  (ADR 0024).
- *Recorded:* `R`, the hash `W` of the written bytes, and the stat (ADR 0024, ADR 0026).

= Options
- *Desired, recorded, missing.* Create, as ADR 0024 said; or re-create and show it in the plan, as
  for links.
- *Not desired, recorded, stat differs.* A conflict; or leave the file, drop the record and warn.
- *Not desired, recorded, missing.* Drop the record (*forget*), as for links.

= Decision
#table(
  columns: (auto, auto, auto, 1fr),
  [desired], [recorded], [live], [result],
  [yes], [no], [absent], [*create*],
  [yes], [no], [present], [*conflict*: "unknown, run `mdot verify`"],
  [yes], [yes], [stat matches, `R == D`, same `mode`], [*noop*],
  [yes], [yes], [stat matches, `R == D`, `mode` differs], [*update*: `chmod` only],
  [yes], [yes], [stat matches, `R != D`], [*update*: download again],
  [yes], [yes], [stat differs], [*conflict*: "changed, run `mdot verify`"],
  [yes], [yes], [absent], [*re-create*; the plan shows it was removed by hand and will be downloaded again],
  [no], [yes], [stat matches], [*delete* (per `on_remove`, ADR 0011)],
  [no], [yes], [stat differs], [*conflict*],
  [no], [yes], [absent], [*forget*: drop the record; the plan shows it],
)

`plan` never adopts a download with no record, since that needs a hash; `mdot verify` does
(ADR 0024).

The author accepted the three new rows as recommended:
- *Re-create, shown in the plan:* the same rule as links, and nothing at that path can be lost. A
  re-create is a network fetch, and with `verify = false` and a moving URL it can fetch different
  bytes, so the user should see it.
- *Conflict when not desired and the stat differs:* a stat mismatch means "maybe changed". After
  `mdot verify` refreshes the stat of an unchanged file, the delete goes ahead; forgetting it would
  leave a file mdot owns behind. This matches ADR 0011 for rendered copies.
- *Forget when not desired and missing:* nothing on disk to protect, as for links.

= Consequences
- Replaces the four-row table of ADR 0024 in `design.typ`. ADR 0024 and ADR 0026 stay as history.
- The table also covers `file.copy` when it is designed, since ADR 0026 made both clauses one
  mechanism.
- For a download delete, a crash between removing `dst` and removing its record lands on the
  *forget* row. This answers ADR 0029's open write order for that case.

= Open
- Whether a stat mismatch still blocks `apply` when the recorded policy is
  `on_remove.files = "keep"`, since mdot would not delete the file anyway.
]
