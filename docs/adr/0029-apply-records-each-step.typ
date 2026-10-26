#import "../template.typ": adr

#adr(number: 29, title: [`apply` records state after each step and stops at the first failure], status: [Accepted (exit code 3 superseded by 0053)], date: [2026-10-23])[
= Context
`apply` re-plans and writes nothing if the plan has any error or conflict (ADR 0016, ADR 0021). A
write can still fail after a clean plan, for example a permission error on link 3 of 5, and mdot
can die between two writes. State must stay accurate, because removal and drift detection depend
on it (ADR 0009).

= Options
- *Order of the two writes per link.* Create the link, then record it in state; or record it,
  then create the link.
- *Directories mdot creates (ADR 0016).* Record after `mkdir`, accepting a leak if mdot dies in
  between; or record before `mkdir`.
- *On a failed write.* Stop; or skip it and try the remaining links.

= Decision
- *State is saved immediately after each link,* so an apply that fails partway can be continued by
  the next `apply`.
- *Link first, then state.* If the state write fails, the next plan sees that the link points to
  the right config and records it (the "adopt into state" row of the 3-way diff). If the link
  fails, nothing is recorded, and the next plan sees it is missing and creates it.
- *Directories use the same order.* If mdot dies between `mkdir` and recording it, the directory is
  never recorded, and removal later leaves it behind. The author accepts that leftover empty
  directory.
- *Stop at the first failed write.* Links already made stay recorded. The user fixes the cause and
  runs `apply` again.
- *Exit code and message.* A failure partway exits with 3. The message names the failed link, says
  what was done and what was not attempted, and says to run `apply` again after fixing the cause.
- *No special Ctrl-C handling.* An interrupt is treated like a crash; the write order already makes
  that safe.

= Consequences
- Continuing after a failure needs no resume logic: the next `apply` plans again, and links already
  made are no-ops.
- Each link costs one state write.

= Open
- Whether an apply that stopped partway gets a generation (ADR 0010).
- The order of writes for deletes and updates. Only creation was decided. For a delete, removing
  the link and dying before removing the record leaves "not desired, recorded, absent", which the
  3-way diff table has no row for yet.
]
