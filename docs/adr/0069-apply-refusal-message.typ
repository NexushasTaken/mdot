#import "../template.typ": adr

#adr(number: 69, title: [`apply` refuses on conflicts with one line that points to `mdot plan`], status: [Accepted], date: [2026-10-27])[
= Context
ADR 0052 and ADR 0068 left open what `apply` prints when it refuses because of conflicts. Facts that
shaped it:

- ADR 0068: `apply` computes the plan without printing it; on conflicts it refuses before the
  question, also with `--yes`. `mdot plan` is the review; `apply` is not.
- ADR 0053: a refusal exits with 1, and nothing on disk was changed by mdot.
- ADR 0050: diagnostics go to stderr as `<word>: <message>`; `conflict:` is red. `hint:` lines are
  not in the first version.
- ADR 0016 and ADR 0052: `plan` reports every conflict, each as a `!` step line followed by its
  `conflict:` line.
- ADR 0068: after a no at the question, nothing more is printed.

= Options
- Only the author's approach was considered: one message that says there is a conflict and points to
  `mdot plan`. Claude asked which prefix word to use and whether the pointer should be a later
  `hint:` line; the author set both aside to keep it simple.

= Decision
From the author:

- *When the plan `apply` computes has a conflict, `apply` prints one message and stops.* The message
  says there is a conflict and to run `mdot plan` to review it. `apply` does not list the conflicts;
  `plan` does.

Accepted additions proposed by Claude (reasons are Claude's):
+ *The line* is `conflict: apply refused; run 'mdot plan' to review`, on stderr. It reuses the
  `conflict:` word (red, ADR 0050), so it needs no new word and no `hint:` line.
+ *No count:* the line does not say how many conflicts there are; `plan` shows them.
+ *Nothing else is printed:* no step lines, no summary, no `Applied: nothing.`, since nothing was
  attempted. This matches the "after a no" rule in ADR 0068.

```
2 | conflict: apply refused; run 'mdot plan' to review
```

= Consequences
- The refusal looks the same for one conflict or many; the user runs `mdot plan` to see which.
- `apply` with `--yes` in a script prints this line and exits 1 (ADR 0053, ADR 0068).
- This `conflict:` line has no path, unlike ADR 0050's `conflict: <path>: <message>` lines.
]
