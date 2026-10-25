#import "../template.typ": adr

#adr(number: 42, title: [No spec-declared defaults; `config.lua` is the only place vars are defined], status: [Accepted], date: [2026-10-25])[
= Context
ADR 0019 parked a `config {}` clause: defaults declared by a spec (`config { git = { user, email } }`)
and overridden by the host. `design.typ` lists it as a planned Phase 4 clause, and says a host file
will later hold `config`. Since then, markers (ADR 0037) and `mdot.vars` (ADR 0038) cover its
motivating case: the author's git name and email are markers that read vars defined in `config.lua`.

ADR 0038 defines base `vars` as `mdot.vars` after `config.lua` alone; the clean filter (ADR 0037)
commits marker values computed from it, and the schema (ADR 0039) is built from it. Base must exist
and be the same on every machine. ADR 0038 left spec-declared defaults open. With them:

- Two specs could declare the same var with different defaults; hosts reaching different specs
  would then have different bases, and the committed value would change with the machine that
  committed.
- A spec reading a var while loading could run before the spec that declares it.

= Options
- *A. Drop it:* `config.lua` stays the only place vars are defined.
- *B. Spec defaults with rules:* mdot reads the declarations of every spec in `specs/`, not only the
  reached ones; a var declared by two specs is an error; declarations are collected before any spec
  code runs (for example from a separate file per spec).
- *C. Keep it parked.*

= Decision
From the author:

- *Option A.* Specs cannot declare defaults. `config.lua` is the only place vars are defined, and
  host files still override them (ADR 0038, 0039).

Claude's arguments, which the author agreed with but did not give as reasons: A keeps one base that
every machine agrees on, as the clean filter needs; the author's five real vars (git name and
email, font, cursor name and size) fit in one file; and it adds no loading pass or error cases.

= Consequences
- Closes ADR 0038's open item on spec-declared defaults, and ADR 0019's parked `config {}`. Both
  ADRs are unchanged.
- The planned `config {}` clause is removed from `design.typ`. A host file holds only `depends` and
  overrides of `mdot.vars`.
- A spec's vars do not live next to the spec.
- If `config.lua` grows too big for one file, splitting it depends on `require`, which ADR 0013
  leaves open.
]
