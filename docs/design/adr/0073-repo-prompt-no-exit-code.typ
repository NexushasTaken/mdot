#import "../template.typ": adr

#adr(number: 73, title: [A no at the repo-path prompt exits with 1], status: [Accepted], date: [2026-10-28])[
= Context
ADR 0062 says a no at the repo-path prompt "stops", but gives no exit code; ADR 0072 left it open.
Facts that shaped it:

- ADR 0053: 0 is success; 1 is a refusal by one of mdot's rules (mdot finished its checks, the answer
  is no, nothing on disk was changed); 2 is an error.
- ADR 0062: the stored repo path is a rule (state belongs to one repo). With no terminal on stdin,
  a mismatch is refused with exit 1. The prompt is shown by both `plan` and `apply`.
- ADR 0068: a no at the `apply` prompt exits 0 and prints nothing more.
- ADR 0072: an empty answer, any answer other than `y`/`yes`, and EOF are all a no.

= Options
- *0,* as a no at the `apply` prompt.
- *1,* a refusal by a rule. Chosen.

= Decision
From the author:

- *A no at the repo-path prompt exits with 1,* following ADR 0053: the repo check is a rule, and a
  no means the rule stops the run.

Accepted addition proposed by Claude (reason is Claude's):
+ *Nothing more is printed after the no.* The `warning:` line above it already says why, and this
  matches ADR 0068's "after a no, nothing more is printed".

```
2 | warning: state belongs to /home/nexus/old-dots, this repo is /home/nexus/dotfiles
2 | continue anyway? [y/N] n
exit 1
```

#table(
  columns: 2,
  [*Case*], [*Exit*],
  [repo mismatch, no terminal (ADR 0062)], [1],
  [repo mismatch, answered no, empty, invalid or EOF (ADR 0072)], [1],
  [`apply? [y/N]` answered no (ADR 0068)], [0],
)

= Consequences
- Both repo-mismatch refusals, with or without a terminal, exit with 1.
- The two prompts differ: a no at the repo-path prompt exits 1, a no at the `apply` prompt exits 0.
  The repo no is a rule winning; the `apply` no is the user choosing not to run now.
- `plan` answered no at this prompt prints no plan and exits 1.
]
