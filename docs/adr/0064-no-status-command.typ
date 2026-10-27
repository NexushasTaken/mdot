#import "../template.typ": adr

#adr(number: 64, title: [No `mdot status` command; `plan` reports drift], status: [Accepted], date: [2026-10-27])[
= Context
`design.typ` listed `mdot status` as "resource drift, read-only (ADR 0031)", but its output was
never designed, and Phase 1 acceptance test step 5 depended on it ("a link retargeted by hand shows
up as drift in `status`").

`plan` already compares desired × recorded × live (ADR 0035). A recorded link that was changed by
hand is a `conflict: drift` row in ADR 0030's table, printed as a `conflict:` line (ADR 0050, ADR
0051), and a plan with a conflict exits with 1 (ADR 0053).

Other docs gave `status` behavior: `--host` applied to it, it never hashed files, it took the
shared lock (ADR 0063), and ADR 0031 said it shows only mdot's own resources.

= Options
- A. `status` compares recorded × live only, without loading specs. It answers "is the machine still
  how mdot left it?" and works when a spec is broken.
- B. `status` runs the same 3-way diff as `plan` and shows it shorter (counts, or conflicts only).
- C. No `status` command; `plan` is the way to see drift.

= Decision
From the author:

- *Option C.* There is no `mdot status` command. The author's reason: it is too similar to `plan`.
- *Removed from the CLI entirely,* not only from Phase 1.

Accepted additions proposed by Claude:

- *Acceptance test step 5:* a link retargeted by hand shows up in `plan` as a `conflict:` line
  (drift), and `plan` exits with 1.
- *`--host`* applies to `plan` only.
- *Other mentions of `status`* are removed from `design.typ` and `research.typ`; the purity and
  drift-detection tests in `research.typ` name `plan`. The parts of ADR 0031 and ADR 0063 about
  `status` no longer apply. ADR 0031's rule stays for `plan`: an edit made through a link is not
  reported.

= Consequences
- Phase 1 has one fewer command to build and test.
- There is no way to check for drift while a spec fails to load: `plan` needs every spec to load.
- `plan`'s output is the only drift report, so its layout (ADR 0051) carries that job too.

= Open
- Whether a drift-only command (option A) comes back in a later phase. It would need its own ADR.
]
