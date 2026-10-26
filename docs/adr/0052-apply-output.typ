#import "../template.typ": adr

#adr(number: 52, title: [Output of `mdot apply`; step lines print when a step finishes], status: [Accepted (exit code 3 superseded by 0053)], date: [2026-10-26])[
= Context
ADR 0051 designed the layout of `mdot plan` and left the output of `mdot apply` open. Plan lines go
to stdout and diagnostics (`error:`, `conflict:`, `warning:`) to stderr (ADR 0050). `apply` stops
at the first failed write and exits with 3 (ADR 0029), whose message was to name the failed link,
say what was done and what was not attempted, and say to run `apply` again. A failed `rmdir` during
a delete is a warning (ADR 0033). In ADR 0051 a spec's conflicts come after its other lines.

Whether `apply` asks for confirmation before it acts (`--yes`, ADR 0047) is a separate decision and
is not part of this ADR.

= Options
- *When step lines appear in `apply`:*
  - X. Only the steps, each printed as it runs, no plan first.
  - Y. The whole plan first, then each step printed again as it runs.
  - Each step printed once, after it finishes.
- *Level 0:* quiet until the summary, or one line per finished step.
- *Steps after a failure:* a count of what was not attempted, a list of them, or nothing.
- *Stream of the summary after a failure:* stdout or stderr.
- *Symbol for a failed or conflicting step:* `!`, `✗`, `x` or `?`.
- *Position of a conflict in `plan`:* after the spec's other lines (ADR 0051), or at its step's
  position.

= Decision
From the author:

- *`apply` reuses `plan`'s layout* (ADR 0051), with a few changes so it reads like an apply.
  No-ops are hidden, as in `plan`.
- *A step line is printed after its step finishes,* whether it worked or failed. The same holds for
  `plan`.
- *A failed step's `error:` line comes right under its step line,* so the failure stands out.
- *In `plan`, a conflict is a step line too,* directly followed by its `conflict:` line, at the
  step's position. This supersedes ADR 0051's "conflicts after the spec's other lines".
- *`!` marks a step that failed (`apply`) or conflicts (`plan`).* Claude proposed it; the author
  called it a reasonable choice. It is ASCII, does not clash with `+ ~ - =`, and works without color.
- *`apply` still stops at the first failure* (ADR 0029), and the steps it did not attempt are not
  reported: they were not attempted, and the error under the failed step is noticeable enough. This
  supersedes "what was not attempted" in ADR 0029's message.
- *The `apply` summary does not count the failure:* a stop always means exactly one failure, so the
  count says nothing. `plan` keeps its conflict count, because it shows every conflict.
- *The summary goes to stdout,* after a failure too. There is no reason to put it on stderr.

Accepted additions proposed by Claude:

- *Summary wording:* `Applied: 2 created, 1 updated, 1 deleted.`, past tense, leaving out counts
  that are zero.
- *Nothing to do:* `apply` prints `No changes.`, as `plan` does.
- *Failure before anything was done:* the summary is `Applied: nothing.`
- *Verbosity:* `apply` has the same `-v` levels as `plan` (ADR 0051).
- *Order and headings* are as in ADR 0051: specs in dependency order, steps in the order the spec
  declares them, and a spec's heading is printed just before its first line.
- *What failed:* since `!` hides whether the step was a create, update or delete, the `error:`
  message says it, as in `could not create link: permission denied`.
- *"Run `apply` again"* from ADR 0029 becomes a `hint:` line, which comes with the other follow-up
  lines (ADR 0050), not in the first version.
- *Exit code:* a failed `apply` still exits with 3 (ADR 0029).

`apply` that fails on its third step (stream on the left):

```
1 | waybar
1 |   + link  ~/.config/waybar -> config
1 | foot
1 |   + link  ~/.config/foot/colors.ini -> colors.ini
1 |   ! link  ~/.config/foot/foot.ini -> foot.ini
2 | error: ~/.config/foot/foot.ini: could not create link: permission denied
1 |
1 | Applied: 2 created.
```

`plan` with a conflict:

```
1 | foot
1 |   + link  ~/.config/foot/colors.ini -> colors.ini
1 |   ! link  ~/.config/foot/foot.ini -> foot.ini
2 | conflict: ~/.config/foot/foot.ini: exists and is not managed
1 |
1 | Plan: 1 to create, 1 conflict.
```

= Consequences
- `plan` and `apply` share one layout and one set of symbols.
- `mdot plan > plan.txt` now shows which resources conflict, as `!` lines; only the reasons, on
  stderr, are missing. This answers part of ADR 0050's open question.
- After a failed `apply`, nothing in the output says that work was left undone; the exit code 3 and
  a new `mdot plan` show it.
- The step lines and their diagnostics alternate between stdout and stderr; they stay in order in a
  terminal because whole lines are written to both (tested in ADR 0051).
- A slow step shows nothing until it finishes.

= Open
- What `apply` prints when it refuses to run because of conflicts (ADR 0016). Depends on the
  confirmation decision.
- Whether `apply` asks for confirmation, and `--yes`.
- Whether slow steps (downloads) need progress output later.
- Colors for `!` and the other symbols.
]
