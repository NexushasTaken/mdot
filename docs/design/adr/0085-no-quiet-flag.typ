#import "../template.typ": adr

#adr(number: 85, title: [No `-q` flag in Phase 1], status: [Accepted], date: [2026-10-29])[
= Context
`design.typ`'s global flags and ADR 0047 list `-v`/`-q`. ADR 0047 decided only that `-q` is a
command-line flag with no `mdot.opt` option; no ADR says what it does.

What constrains it:

- ADR 0051: `-v` levels only add output. Level 0 (the default) shows changes, conflicts and one
  summary line (`No changes.` when there is nothing to do). Errors and warnings are shown at every
  level.
- ADR 0078: `mdot.print` output is shown at every `--verbose` level.
- ADR 0050: the plan, the summary and `mdot.print` go to stdout; `error:`, `conflict:` and
  `warning:` go to stderr.
- Exit codes: 0 ok, 2 conflict, 3 error.

= Options
- *Drop `-q`* from Phase 1.
- *Keep it,* hiding:
  - A. the summary line only;
  - B. everything on stdout (the same as `> /dev/null`, except for deciding whether `mdot.print`
    survives);
  - C. stdout and warnings;
  - D. everything, leaving only the exit code.

  C and D break ADR 0051's "errors and warnings are shown at every level".

= Decision
From the author:

- *`-q` is dropped from Phase 1.* The author's reason: `-v` already exists. The author also called
  Claude's reasons a good point: a script that needs only the result reads the exit code;
  `> /dev/null` hides the plan and keeps conflicts, warnings and errors on stderr; and level 0 is
  already small.

Accepted additions proposed by Claude:

- *Added later if needed:* if a real need for quiet output appears, `-q` comes back with its own
  ADR. Adding a flag later is easy; removing one people already use is not.
- *ADR 0047 is not edited.* Its index status notes that `-q` was dropped by this ADR.
- *`design.typ`:* the global flags are `--repo <dir>`, `-v` and `--color`.
- *`todo.typ`:* the item is narrowed to `--color`.

= Consequences
- Phase 1 has one fewer flag to parse, document and test, and no rule for how `-q` and `-v`
  combine.
- Quiet output relies on redirection and exit codes. `mdot.print` lines go to stdout, so
  `> /dev/null` hides them too.

= Open
- Nothing for `-q`. `--color` is a separate item.
]
