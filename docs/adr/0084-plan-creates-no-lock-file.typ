#import "../template.typ": adr

#adr(number: 84, title: [Only `apply` creates the state directory and the lock file], status: [Accepted], date: [2026-10-29])[
= Context
Two documents disagreed:

- `research.typ` (Evaluation criteria, *Purity*): `mdot plan` never modifies the filesystem,
  testable by running it against a read-only `$HOME`.
- ADR 0063: the state directory and `<state dir>/lock` are created if missing, also by `plan`.

On a machine where mdot has never run, the first `plan` would create the state directory and an
empty lock file, which breaks the Purity criterion.

`plan` only reads. It locks so it does not read `state.json` while an `apply` changes it (ADR 0063).
It never writes a record, so running it without the lock cannot lose one.

= Options
- A. `plan` and `apply` both create the lock file (ADR 0063 as written); the Purity criterion is
  reworded to allow it.
- B. Only `apply` creates the state directory and the lock file. Chosen.
- C. `plan` never locks. Dropped: it gives up the protection ADR 0063 chose.

= Decision
From the author:

- *Option B.* `plan` never creates the state directory or the lock file; `apply` does, as in
  ADR 0063.

Accepted additions proposed by Claude (reasons are Claude's):

+ *A missing lock file means no lock.* If `<state dir>/lock` does not exist, `plan` runs without
  locking and reads whatever state exists (none on a machine where `apply` never ran). The same
  rule covers a lock file deleted by hand.
+ *`plan` opens the lock file read-only,* so it works with a read-only `$HOME`. On Linux a shared
  `flock` works on a file opened read-only and still blocks an exclusive one (checked in a
  throwaway test).
+ *Later commands follow the same split:* read-only ones (`generations`) never create the lock
  file; commands that write state (`adopt`, `rollback`) create it like `apply`.
+ *Recorded as a new ADR* that supersedes only ADR 0063's "created if missing, also by `plan`"
  point. The rest of ADR 0063 stands. The Purity criterion in `research.typ` stays as written.

#table(
  columns: 3,
  [*Lock file*], [*`plan`*], [*`apply`*],
  [missing], [runs without a lock, creates nothing], [creates the state directory and lock file, locks exclusively],
  [exists], [opens it read-only, shared lock], [exclusive lock],
)

= Consequences
- `plan` writes nothing to disk, so the Purity criterion holds as written.
- A `plan` that overlaps the first `apply` on a machine can show an out-of-date plan. After that
  `apply`, the lock file exists for good (ADR 0063 never deletes it), so later runs lock normally.
- Closes the `todo.typ` item "Purity vs the lock file".

= Open
- *Read-only locking on Windows* (`LockFileEx` on a handle opened for reading only): not checked.
]
