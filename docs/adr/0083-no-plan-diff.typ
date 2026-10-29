#import "../template.typ": adr

#adr(number: 83, title: [No `plan --diff` in Phase 1], status: [Accepted], date: [2026-10-29])[
= Context
`design.typ`'s CLI table listed `mdot plan [--diff]`, but no section or ADR said what `--diff`
shows. It came from the first design rewrite (2026-10-06), in the same table as `apply --force` and
`mdot status`, both since dropped (ADR 0016, ADR 0064). ADR 0047 lists `plan --diff` among the
command flags only to make it flag-only.

In other tools the name means a content diff: `ansible-playbook --check --diff` shows the
line-by-line file changes a run would make, `chezmoi diff` how target files would change.

Phase 1 manages links only. For a link mdot owns only whether it exists and where it points (ADR
0031); an edit made through the link is a repo change that `plan` does not report. Everything about
a link is already on its plan line (`dst -> src`, ADR 0051) or at `-v=2` (desired / recorded /
live).

= Options
- A. Keep `--diff` and give it a meaning for links.
- B. Remove it until a resource kind with content of its own exists.

= Decision
From the author:

- *Option B.* `plan` has no `--diff` flag, and it is removed from the CLI table. The author's
  reason: it was never defined, and with links only there is nothing for it to show.

Accepted additions proposed by Claude:

- *Recorded as an ADR,* because ADR 0047 names `plan --diff`; that mention no longer applies.
- *A Later-phases item in `todo.typ`* for a content diff of content kinds (`file.copy`,
  `net.download`, `render` / `patch`).

= Consequences
- Phase 1 has one fewer flag to parse, document and test.
- The common 3-way table's "show the diff" in its drift row has no command behind it yet; the
  Links table, which governs Phase 1, does not use it.

= Open
- Whether a content diff comes back for content kinds, and in what form (a flag, a `-v` level or a
  command). It would need its own ADR.
]
