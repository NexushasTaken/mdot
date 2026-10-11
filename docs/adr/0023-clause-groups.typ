#import "../template.typ": adr

#adr(number: 23, title: [Resource clauses are grouped: `link` becomes `file.link`], status: [Accepted], date: [2026-10-11])[
= Context
`link` is the only resource clause today (ADR 0015, 0022), but `copy` and `download` are expected.
A flat namespace would end up with `link`, `copy`, `download`, and later `render`, `patch` and
`sysfile`, with nothing in the name saying what each one acts on. Comtrya names its actions the same
way (`file.link`, `file.copy`, `directory.create`).

= Options
- Keep every clause flat. Simple, but the global namespace fills up and `download` reads like a
  file action when it is not.
- Group every clause, including `depends` and `enabled`. Uniform, but `file.depends` is nonsense.
- Group resource clauses and keep spec-level clauses flat. Chosen.

= Decision
- A clause that puts a managed resource on the system is called as `group.clause(...)`. The group
  is named after what the clause acts on, not how it works.
  - `file.link` replaces `link` (ADR 0015, 0022). Its forms, arguments and errors are unchanged,
    including the batch form `file.link { names..., into = dir, dot? }`.
  - `file.copy` and `net.download` are planned, not designed. `download` is `net.*` because it is
    not an action on a file. Neither is part of Phase 1.
- Spec-level clauses stay flat: `depends`, `enabled`, `package`, `config`, `on_remove`.
- The rule is not strict. A clause is grouped only when the group name reads naturally; `file.depends`
  would not. Later clauses (`render`, `patch`, `sysfile`) pick a group or stay flat when they are
  designed.
- There is no bare `link` alias. One spelling per clause.
- Every resource clause produces the same kind of resource whatever its group, so ADR 0016
  (conflicts) and ADR 0021 (same-`dst` errors) apply across groups: `file.link` and `file.copy` to
  the same `dst` is an error.

= Consequences
- Amends ADR 0015 and ADR 0022: read `link` in them as `file.link`. Those ADRs are kept unchanged as
  history, as are the `link` mentions in ADR 0016 and 0021.
- A bare `link(...)` call is an unknown-name error in the sandbox. The loader exposes `file` as one
  table of constructors, so adding a group later does not touch the existing ones.
- A spec that finds `file.link` too long can write `local link = file.link`.
- Open: whether `sysfile` (ADR 0014, on hold) becomes `file.copy { scope = "system" }` instead of
  its own clause. Decide when Phase 3 is designed.
- Open: `net.download` needs a required hash so the diff has something stable to compare, and
  specs stay pure (ADR 0013). Decide when it is designed.
]
