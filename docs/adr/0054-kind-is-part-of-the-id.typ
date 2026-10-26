#import "../template.typ": adr

#adr(number: 54, title: [The kind is part of the resource ID], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0034 matches desired and recorded resources by ID but left open what an ID is made of. Its
first open item: if a spec turns `~/.foo` from a link into a download, is that one ID with a new
kind, or two IDs?

Two situations look alike but are different:
- *A, two clauses in one plan:* a `file.link` and a `net.download` both write `~/.foo` now.
- *B, one clause changed over time:* the last `apply` recorded a link at `~/.foo`; the spec now has a
  `net.download` at `~/.foo` instead. Desired is a download, recorded is a link.

Constraints: ADR 0021 (same `dst` twice is a plan-time error), ADR 0034 (one owner per ID; live is
observed only for IDs that come out of the match), ADR 0035 (generic classify, per-kind decide, IDs
sorted, the plan is data), ADR 0032 (a desired, unrecorded download with something present at its
path is a conflict), ADR 0011 (`on_remove`).

= Options
For the ID:
+ *The kind is part of the ID.* In B, the link and the download are two IDs. Chosen.
+ *The ID is the output path only;* classify gets a "kind changed" case that every kind handles.
+ *A kind change is a conflict;* the user applies once without the old clause, then again with the
  new one.

For the package ID, the author first proposed name plus version (`hyprland-0.56.2-4`, as `pacman -Qi`
shows it). Dropped: the desired side (`package("hyprland")`) has no version, and every upgrade would
change the ID, so the planner would see a removal plus a new package.

For B: rules 1 and 2 below together, or option 3 as a fallback. Rules 1 and 2 chosen.

= Decision
From the author:
- *An ID is a string,* computed at runtime by a function from the clause data. It is not a stored
  field.
- *Every output of a clause has its own ID.* A clause can have many outputs; for `file.link`,
  including the batch form (ADR 0022), each ID comes from its `dst`.
- *A package's ID is its name only,* without the version.
- *Two clauses of different kinds with the same output are a conflict.* mdot shows the user which
  clauses clash. Situation A is this case.
- *The kind is part of the ID.* Desired and recorded are not merged just because their output is the
  same; the kind must match too.
- *Under `on_remove.files = "keep"` the old resource is forgotten and left on disk.* A new resource at
  that path then conflicts, as with any file mdot did not make. The author considers this the right
  outcome, because the user chose that policy. (ADR 0011 does not spell out what `keep` does; this is
  the author's reading of it.)

Accepted additions:
+ *Apply runs in phases:* deletes and forgets first, then updates, then creates. IDs stay sorted
  within each phase, so the same input still gives the same plan (ADR 0035). A slot is free before
  something new fills it.
+ *A slot freed in this plan counts as absent for the new kind.* If a desired-only ID's slot (see
  below) is held by a recorded-only ID of another kind, and that ID's step is *delete*, the
  desired-only ID is classified with live `absent`. Otherwise the plan would report B as a conflict before `apply`
  runs, because the old resource is still on disk when the plan is made. Under `keep` the old step
  is *forget*, not delete, so the slot is not freed and the new resource conflicts, as above.
+ *Scope:* rule 2 is implemented when a second kind that writes files exists (downloads). Phase 1,
  with links only, needs rule 1 only.
+ *String format:* `<kind>:<output>`, for example `link:~/.foo`, `pkg:hyprland`. The prefix keeps IDs
  of different kinds from clashing (`pkg:hyprland` and a later `unit:hyprland`). The `~/.foo` here
  is only an example; which form of the path is used is open.
+ *The same-output check compares slots across kinds, not IDs.* With the kind in the ID, two
  clashing clauses of different kinds no longer share an ID, so ADR 0034's duplicate-ID check alone
  would miss situation A. ADR 0021's same-`dst` check is this check for files.
+ *`design.typ`'s resource table* gives each identity as kind + output.

Slots (added the same day, after the author objected to a `path` function in the planner):
- From the author: the planner is generic and must not know about paths (`planner.typ`). A package
  occupies a place too: installing one is like creating a file at a path, an entry in the package
  manager's database instead of on disk.
- Accepted addition: *every resource occupies a slot,* a string `<world>:<output>` that names the
  place it takes in the world: `fs:~/.foo` for a link or a download, `pacman:hyprland` for a package.
  The world keeps places of different worlds apart, so a file named `hyprland` and the package
  `hyprland` never clash. The ID says _what_ (matching uses it); the slot says _where_ (conflicts and
  freed places use it). The planner only compares slots for equality and does not know what a world
  means. Every kind has a slot; a kind with no place in the world does not fit the model
  (`design.typ`).

= Consequences
- Closes ADR 0034's first open item.
- Situation B plans as a delete of the old ID and a create of the new one, with no conflict, when the
  old resource is still what mdot left.
- The planner gets one step before classify that adjusts live for freed slots (rule 2). The same
  rule covers packages: a later kind that installs `hyprland` from another source frees and fills
  `pacman:hyprland` the same way. `classify`
  and the decide tables do not change.
- `apply` no longer runs steps in plain sorted-ID order (ADR 0035), but in phases.

= Open
- *Is the spec part of the ID?* (ADR 0034)
- *Which form of the path is used:* as written (`~/...`) or expanded. (ADR 0034)
- *What `plan` shows for B:* two lines (delete and create) or one "replace" line (ADR 0051).
]
