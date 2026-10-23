#import "../template.typ": adr

#adr(number: 34, title: [The planner matches desired and recorded resources by ID], status: [Proposed], date: [2026-10-23])[
= Context
ADR 0009 requires every kind to define its *identity*, and `design.typ` lists one per kind (target
path; target path + query for `Patch`). `design.typ` says the planner compares desired × recorded ×
live "for each resource identity", but not how that list of identities is built.

The author found the gap while sketching a generic 3-way reconcile: a spec only says what is
desired. If a spec is removed, nothing in the specs mentions its resources any more, so the planner
needs another way to find them, or their records are left out and forgotten.

Constraints from other ADRs:
- ADR 0021: the same `dst` in two reachable specs, or in two clauses, is a plan-time error. On the
  desired side a path occurs at most once.
- ADR 0011: the removal policy is recorded at apply, so a recorded-only resource can still be acted
  on.
- ADR 0020: `dst` expands only a leading `~`.

= Options
Not discussed yet. See Open.

= Decision
- *Every resource has an ID.* Desired resources get theirs from the clauses, recorded resources from
  state.
- *The planner collects all desired resources and all records, then matches them by ID.* This gives
  three groups:
  - desired only: new;
  - in both: compare;
  - recorded only: the spec or clause was removed.
- Each group is then decided by the kind's own table (ADR 0009).

Accepted additions (2026-10-24, with ADR 0035):
- *Live is observed only for IDs that come out of the match.* The whole filesystem cannot be listed.
- *Two desired resources with the same ID are an error:* one owner per ID. For paths this is ADR
  0021's same-`dst` rule.
- *"Identity" means only the resource ID.* The download's hash or `url` (`D`/`R`) is renamed to its
  _content key_ in `design.typ`.

= Consequences
- Removing a spec or a clause is visible to the planner, through the recorded-only group.
- State must keep enough per record to act on it without a spec.

= Open
- *Is the kind part of the ID?* If a spec turns `~/.foo` from a link into a download, is that one ID
  with a new kind, or two IDs (delete the link, create the download)? What does `plan` show?
- *Is the spec part of the ID?* If `nvim/` is renamed to `neovim/` and still links the same `dst`,
  is that a delete + create, or nothing?
- *Which form of the path is the ID:* as written in the spec (`~/...`), or expanded to an absolute
  path? This matters if state moves between machines or users with different home directories.
]
