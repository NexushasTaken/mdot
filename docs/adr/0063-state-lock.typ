#import "../template.typ": adr

#adr(number: 63, title: [An OS file lock on the state directory: shared for readers, exclusive for `apply`], status: [Accepted], date: [2026-10-27])[
= Context
`design.typ` (State and generations) and ADR 0062 left open what happens when two mdot runs overlap.

Facts that shaped it:
- ADR 0062: one state directory per user, `$XDG_STATE_HOME/mdot/`, so every run shares one
  `state.json`.
- ADR 0059, ADR 0060: `state.json` is written atomically (temp file, then `rename`). A reader sees
  the whole old file or the whole new file.
- ADR 0033: `apply` reads state, plans, changes the disk, then writes state.
- `design.typ`: there is no special Ctrl-C handling.

Atomic writes do not stop a *lost update*: two `apply` runs both read the same state, each changes
the disk, and the second write replaces the first. The first run's links stay on disk with no
record.

= Options
*Which runs lock:*
+ *Every `plan` and `apply` locks exclusively.* The author's first answer.
+ *Readers share, `apply` excludes.* Chosen.

*What a run does when the lock is taken:*
+ *Wait* until the other run finishes.
+ *Error right away.* Chosen.

*How the lock is made:*
+ *A lock file by existence:* create it, delete it when done. A crash leaves it behind (a stale
  lock) until it is deleted by hand.
+ *An OS file lock* (`flock` on Linux, `LockFileEx` on Windows): the kernel releases it when the
  process exits, however it exits. Chosen.

= Decision
From the author:
- *`plan` and `apply` always lock.* For `plan` and `status` the lock is "read only": they take a
  shared lock, so two of them can run together. `apply` takes an exclusive lock, which excludes
  every other run that locks.
- *Other commands still run while the lock is held:* `specs`, `--help`, `--version`.
- *A run that cannot get the lock errors right away;* it does not wait.
- *Accepted consequence:* while `apply` waits at its confirmation prompt (ADR 0052), it holds the
  exclusive lock, so `plan` and `status` in another terminal error until it finishes.
- *The lock is an OS file lock,* so a crash or Ctrl-C never leaves mdot locked.

Accepted additions proposed by Claude (reasons are Claude's):
+ *The locked file is `$XDG_STATE_HOME/mdot/lock`,* not `state.json`. An atomic write replaces
  `state.json` with a new file, so a lock on the old one would protect nothing.
+ *A run takes the lock before it reads `state.json` and holds it until it exits.* Locking only
  around the write would still allow the lost update.
+ *The state directory and the lock file are created if missing,* also by `plan` and `status`.
  *The lock file is never deleted:* deleting it lets one run lock the old file while another creates
  a new one, and both think they hold the lock.
+ *Exit code 1* (ADR 0053): mdot checked and the answer is no; nothing was changed.
+ *The message names the state directory, not the other command:*
  `error: another mdot run is using <state dir>; try again when it finishes`. An OS lock does not
  say who holds it, and the holder may be a reader.
+ *Later commands follow the same split:* commands that write state (`adopt`, `rollback`) take the
  exclusive lock; read-only ones (`generations`) take the shared lock.

#table(
  columns: 3,
  [*Holding*], [*Starting*], [*Result*],
  [`plan` / `status` (shared)], [`plan` / `status`], [both run],
  [`plan` / `status` (shared)], [`apply`], [`apply` errors, exit 1],
  [`apply` (exclusive)], [`plan` / `status`], [the reader errors, exit 1],
  [`apply` (exclusive)], [`apply`], [the second `apply` errors, exit 1],
  [anything], [`specs`, `--help`, `--version`], [runs, no lock],
)

= Consequences
- Two overlapping `apply` runs can no longer lose a record.
- The lock is advisory: it only stops other mdot runs. Editing files or `state.json` by hand is not
  blocked.
- OS file locks may not work reliably on network filesystems (NFS). This matters only if the state
  directory is on one.
- A script that runs `plan` while an `apply` is waiting for an answer gets exit 1 and must retry.
- Closes ADR 0062's open item on locking.

= Open
- *The state directory on macOS and Windows* (ADR 0062), and with it the lock file's path there.
]
