#import "../template.typ": adr

#adr(number: 33, title: [Link updates and deletes change the disk first, then state], status: [Accepted], date: [2026-10-23])[
= Context
ADR 0029 decided the write order for creating a link (link first, then state) and left the order
for updates and deletes open. ADR 0030 gave links their 3-way diff table, with *update* (replace
mdot's own link), *delete* (per `on_remove`, ADR 0011) and *forget* (recorded but absent). A delete
also tries to `rmdir` the parent directories mdot recorded, deepest first (ADR 0016).

Requirement: if mdot dies between two writes, the next `plan` must land on a row of ADR 0030's table
that does the right thing, never on a conflict mdot caused itself, and never lose track of something
mdot owns. State is saved after each step and `apply` stops at the first failure (ADR 0029).

Example of an update: the spec folder `specs/hypr/` is renamed to `specs/hyprland/`, the spec still
has `dst = "~/.config/hypr"`. Live and recorded are `~/.config/hypr -> specs/hypr/config` (now
dangling); desired is `specs/hyprland/config`. The `readlink` string still matches the record
(ADR 0030), so the row is *update*.

= Options
- *Delete A:* unlink, `rmdir` the recorded parents, drop the record. A crash after the unlink lands
  on *forget*.
- *Delete B:* drop the record, then unlink. A crash in between leaves a link that is neither desired
  nor recorded, so mdot no longer knows it is its own and it stays forever.
- *Update U1:* unlink the old link, make the new one, update the record. A crash after the unlink
  lands on *re-create*; a crash after the new link lands on *adopt*. `dst` is missing for a very
  short moment.
- *Update U2:* make the new link at a temporary name, `rename` it over `dst` (atomic on Linux), then
  update the record. `dst` is never missing, but a crash before the `rename` leaves a temporary link
  that no row of the table covers.
- *Update U3:* update the record first, then swap the link. A crash in between leaves state ahead of
  the disk, which lands on *conflict: drift*.
- *Forget* with or without trying the recorded `rmdir`s.

= Decision
- *Delete: A.* Unlink → `rmdir` the recorded parents, deepest first → drop the record. B can leave a
  link mdot no longer knows it owns.
- *Update: U1.* Unlink the old link → make the new one → update the record. The author chose it
  because it is simpler.
- *Forget also tries the recorded `rmdir`s,* so a crash between the unlink and the `rmdir`s does not
  leave empty directories behind.

Accepted additions:
- A `rmdir` on a directory that is already gone counts as done, not an error.
- *Forget* always tries the `rmdir`s, whatever the cause (a crash or a hand removal; mdot cannot tell
  them apart).
- One state write per update or delete, after all of its disk steps, as ADR 0029 does for creates:
  state may lag the disk, never lead it.
- A `rmdir` that fails for a reason other than "not empty" or "missing" (for example a permission
  error) is treated like "not empty": the directory is left, dropped from state, and a warning is
  shown.

= Consequences
- Answers ADR 0029's and ADR 0030's open write order for links.
- A crash after U1's unlink lands on *re-create*, and the plan says the link was "removed by hand",
  which is wrong in that case. This is the accepted cost of U1.
- If the unlink works but the new symlink fails, `apply` stops (ADR 0029) and the next plan
  re-creates the link.
- During an update, `dst` does not exist for a very short moment. A program reading it then finds
  nothing.

= Open
- Whether U2 is needed later, for files that are read constantly.
- Behavior on Windows (not checked).
- Whether an apply that stopped partway gets a generation (ADR 0029).
]
