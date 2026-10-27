#import "../template.typ": adr

#adr(number: 68, title: [`apply` asks once as a guard against running it by accident; `--yes` skips it], status: [Accepted], date: [2026-10-27])[
= Context
ADR 0052 left open whether `apply` asks for confirmation, and what `--yes` does. Facts that shaped
it:

- `design.typ`: "Nothing destructive without consent. Deleting, overwriting or uninstalling needs
  confirmation."
- ADR 0016: no overwriting, no `--force`; `plan` reports all conflicts, and `apply` re-checks every
  link before changing anything.
- ADR 0030 and the planner tables in `design.typ`: mdot updates or deletes a resource only when the
  live value matches what it recorded. Anything else (unmanaged, drifted, changed by hand) is a
  conflict.
- ADR 0047: `--yes` exists and is only a command-line flag, not an `mdot.opt` option.
- ADR 0053: `apply` refusing because of conflicts exits with 1.
- ADR 0062: the repo-path prompt is `continue? [y/N]` on stderr, default No; `--yes` does not answer
  it; with no terminal on stdin mdot refuses with exit 1. After a yes, `apply` "still asks its own
  confirmation".
- ADR 0063: `apply` holds the exclusive lock while it waits at its prompt.
- ADR 0052: `apply` prints each step line once, after the step finishes, then a summary.

= Options
- *How often `apply` asks:*
  - A. Every run asks. Chosen.
  - B. Only the very first `apply` (no state yet) asks.
- *Where the question comes:*
  - S. Before planning.
  - T. After planning: refuse on conflicts and skip the question when there is nothing to do. Chosen.
- *What the user sees before answering:*
  - The plan, printed as `mdot plan` prints it, then the question. Proposed by Claude, rejected: it
    would print the steps twice, and `apply` is not a review.
  - R1. A bare question. Chosen.
  - R2. The plan's counts in the question (`1 to create, 1 to delete. apply? [y/N]`).

= Decision
From the author:

- *Every `mdot apply` asks once,* before anything is applied. It never asks again per step.
- *Order:*
  ```
  apply()
    plan = make_plan()                 # computed, not printed
    if conflicts -> refuse (exit 1)
    if plan empty -> "No changes."
    ask "apply? [y/N]"
    if no -> return
    do_apply(plan)                     # ADR 0052 output, unchanged
  ```
- *The question is a bare guard (R1);* it shows no plan and no counts. The author's reasons:
  - The question guards against typing `mdot apply` by accident; it shows that the command is about
    to run.
  - `mdot plan` is the review; `apply` is not.
  - "Nothing destructive without consent" is already covered by conflicts: mdot only changes what it
    recorded, and only while the live value still matches the record. Whatever mdot did not make, or
    that changed since, is a conflict and is never touched.
- *`apply`'s output is ADR 0052's,* unchanged: each step line once, after its step finishes, then the
  summary.
- *`--yes` skips the question.*
- *No terminal on stdin and no `--yes`:* mdot refuses with exit 1, as in ADR 0062.
- *Answering no:* nothing is applied, exit 0.

Accepted additions proposed by Claude (reasons are Claude's):
+ *The question goes to stderr, `[y/N]`, default No,* as in ADR 0062, so `mdot apply > log` still
  shows it. `apply? [y/N]` is an example; the exact wording is part of the shared prompt mechanics
  (Open).
+ *`--yes` never gets past conflicts:* the refusal comes before the question. This follows from the
  order and ADR 0016 (no `--force`), and is written down so `--yes` is not read as "force".
+ *The message with no terminal* is
  `error: cannot ask for confirmation: stdin is not a terminal; use --yes`. It names the fix.
+ *After a no, nothing more is printed.* `Applied: nothing.` would suggest something was attempted.
+ *`design.typ`'s principle "Nothing destructive without consent"* says where consent comes from in
  Phase 1: for anything mdot did not make, from the conflict rule (ADR 0016); the `apply` question
  only guards against running `apply` by accident (the author's reasoning above).

A run that creates one link and deletes another (stream on the left):

```
2 | apply? [y/N] y
1 | foot
1 |   + link  ~/.config/foot/foot.ini -> foot.ini
1 |   - link  ~/.config/foot/old.ini
1 |
1 | Applied: 1 created, 1 deleted.
```

#table(
  columns: 3,
  [*Case*], [*What happens*], [*Exit*],
  [conflicts (with or without `--yes`)], [refused before the question], [1],
  [empty plan], [`No changes.`, no question], [0],
  [answer yes, or `--yes`], [the steps and the summary (ADR 0052)], [0, or 2 if a step fails],
  [answer no], [nothing more], [0],
  [no terminal, no `--yes`], [the `error:` line], [1],
)

= Consequences
- `apply` never shows what it will do before the question. A user who skips `mdot plan` answers
  without seeing the changes and sees them only as the step lines print.
- A script or cron job must pass `--yes`; without it `apply` exits with 1 and changes nothing.
- While the question waits, `apply` holds the exclusive lock (ADR 0063), so other runs error.
- With a moved repo, a run shows the ADR 0062 prompt, then this one.
- An answer of no exits 0, so a script cannot tell "declined" from "applied" by the exit code;
  scripts use `--yes` anyway.

= Open
- What `apply` prints when it refuses because of conflicts (ADR 0016). Next todo item.
- Prompt mechanics shared with ADR 0062: wording, how an answer is read, what counts as yes, what
  EOF or Ctrl-C at the prompt does.
- Progress output for slow steps, and colors (ADR 0052).
]
