#import "../template.typ": adr

#adr(number: 53, title: [Exit codes: 0 success, 1 refused by a rule, 2 error], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0050 left open that exit code 2 was both clap's code for a usage error and mdot's code for a
conflict. ADR 0029 (repeated in ADR 0052) gives exit code 3 to an `apply` that fails partway. The
"0 ok / 2 conflict / 3 error" codes in ADR 0050's context come from the tiny C++ CLI (`6210682`);
by `cadbba9` the C++ `main` returned `EXIT_FAILURE` for everything, and the Rust port
(`src/bin/mdot.rs`) does the same, so today conflicts and errors both exit with 1.

clap 4 (checked in `clap_builder` 4.6.7) exits with 2 on a usage error and with 0 for `--help` and
`--version`. ADR 0050 decided that a conflict is not an error.

= Options
- A. 0 ok / 2 conflict / 3 error, with clap's usage error moved to another code.
- B. 0 ok / 1 conflict / 2 error, as `diff` and `grep` do (1 is a result, 2 is trouble).
- C. 0 ok / 1 error / 2 usage / 3 conflict.
- D. Keep 0 / 2 / 3 and accept the overlap with clap.
- A separate code for an `apply` that failed partway (state changed) versus one that failed before
  it started.

= Decision
From the author:

- *0* is any kind of success.
- *1* is a conflict, or any other case where mdot will not do it because of its rules.
- *2* is a general error.

This is option B, widened so that 1 covers every refusal by a rule, not only conflicts.

Accepted additions proposed by Claude (the author accepted Claude's recommendations as a whole,
without reasons of their own):

- *The line between 1 and 2:* 1 means mdot finished its checks and the answer is no; nothing on disk
  was changed by mdot. 2 means mdot could not finish its job.
- *What gives which code:*
  - *0:* `plan` with or without changes, a successful `apply`, `No changes.`, `--help`, `--version`.
    Warnings do not change the code.
  - *1:* `plan` with at least one conflict; `apply` refusing to run because of conflicts (ADR 0016);
    a spec that loads but breaks one of mdot's rules, such as two specs with the same `dst`
    (ADR 0021).
  - *2:* a usage error (clap's own code, kept as is); a spec file or state that cannot be read; a
    Lua error while loading a spec (the spec never got as far as the rules); a failed write during
    `apply`.
- *Pending changes are success.* `plan` does not get a separate code for "there is something to do"
  (as `terraform plan -detailed-exitcode` has).
- *When both happen,* 2 wins over 1: a run with a conflict and an error exits with 2.
- *A failed `apply` exits with 2,* not 3. This supersedes the exit code in ADR 0029 and ADR 0052.
- *No separate code for "failed partway".* The output already shows which steps ran (ADR 0052), and
  a new `mdot plan` shows what is left.
- *Not part of the contract:* a Rust panic exits with 101 and is a bug; a run killed by a signal
  gets the code the shell gives it.

#table(
  columns: 2,
  [*Code*], [*Meaning*],
  [0], [success, including pending changes and warnings],
  [1], [refused by a rule: a conflict, or a spec that breaks a rule],
  [2], [error: usage, unreadable file, Lua error, failed write],
)

= Consequences
- clap needs no special handling: its usage error already exits with 2.
- A script can tell "fix your specs or the files they clash with" (1) from "something broke" (2).
  It cannot tell a failed `apply` that changed things from one that changed nothing.
- `mdot.rs` must return 1 or 2 instead of 1 for everything.
- Whether loading stops at the first broken spec or reports every one (ADR 0050, Open) does not
  change the code: any load error gives 2.
]
