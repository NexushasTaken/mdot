#import "../template.typ": adr

#adr(number: 30, title: [The 3-way diff for links], status: [Accepted], date: [2026-10-23])[
= Context
ADR 0009 (Proposed) says the planner compares *desired* (specs) × *recorded* (state) × *live*
(system) per resource, with a generic seven-row table in `design.typ`. For links that table left
cases without a row: a recorded link that is missing on disk (still desired, or not), and a link
whose desired `src` changed since the last apply. ADR 0029 also left "not desired, recorded,
absent" open.

Constraints: mdot never overwrites, and a link mdot made that was retargeted is a conflict (ADR
0016). A link is made first and recorded second, so a correct but unrecorded link is adopted (ADR
0029). Deletes follow the recorded `on_remove` policy (ADR 0011). A link "matches" when its
`readlink` string equals the absolute, normalized `src` (`link-rules.typ`).

= Options
- *Recorded, still desired, missing on disk.* Re-create it; treat it as a conflict; or re-create it
  and show in the plan that it was removed by hand.
- *Re-creating vs. ADR 0016's "no automatic repair of drift".* A narrow exception for missing links;
  or a change to ADR 0016.
- *Desired `src` changed, live still matches the record* (the spec was renamed). Update; or
  conflict.
- *Recorded, not desired, missing on disk.* Drop the record silently; drop it and show it in the
  plan; or conflict.
- *Live matches desired but not the record* (fixed by hand). Adopt; or conflict.

= Decision
#table(
  columns: (auto, auto, auto, 1fr),
  [desired], [recorded], [live], [result],
  [yes], [no], [absent], [*create*],
  [yes], [no], [link → desired `src`], [*adopt* into state (nothing changes on disk)],
  [yes], [no], [anything else], [*conflict*],
  [yes], [yes], [link → recorded `src` = desired `src`], [*noop*],
  [yes], [yes], [link → recorded `src` ≠ desired `src`], [*update*: replace mdot's own link],
  [yes], [yes], [absent], [*re-create*; the plan shows it was removed by hand],
  [yes], [yes], [link → desired `src` ≠ recorded `src`], [*adopt*: update the record, nothing changes on disk],
  [yes], [yes], [anything else], [*conflict: drift* (ADR 0016)],
  [no], [yes], [link → recorded `src`], [*delete* (per `on_remove`, ADR 0011)],
  [no], [yes], [absent], [*forget*: drop the record; the plan shows it],
  [no], [yes], [anything else], [*conflict*],
)

Re-creating a missing link is a narrow exception to ADR 0016, not a change to it: only a missing
link is repaired, because nothing at that path can be lost. A link that points elsewhere is still a
conflict.

= Consequences
- ADR 0029's open row ("not desired, recorded, absent") is answered: *forget*.
- ADR 0009 stays Proposed for the resource model and the link/git ownership split.

= Open
- The write order for updates and deletes (ADR 0029).
]
