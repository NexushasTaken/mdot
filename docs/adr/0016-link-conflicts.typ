#import "../template.typ": adr

#adr(number: 16, title: [Link conflicts are hard errors; parent directories are tracked], status: [Accepted], date: [2026-10-10])[
= Context
ADR 0015 defined `link(src, dst)` but not what happens when `dst` already exists. The old first-run
table assumed a missing repo slot could trigger an adopt prompt; a missing `src` is now a load error.

= Options
- Conflict is an error; or conflict is replaced with a backup behind `--force`.
- A link that state says mdot created but that now points elsewhere is repaired (drift), or is a
  conflict like any other.
- Missing parent directories are an error, or mdot creates and tracks them.

= Decision
mdot never overwrites. If `dst` is missing it creates the link; if `dst` is a symlink to our `src`
it does nothing; any other state (symlink elsewhere, real file or directory, dangling symlink) is a
conflict and a hard error. There is no `--force`. `plan` reports all conflicts, and `apply`
re-checks every link before changing anything. A link that mdot created and that was later
retargeted is also a conflict; the error says it drifted, and the user fixes it. Errors must say
what was expected and what was found.

Missing parent directories are created and recorded in state. On removal, recorded directories are
removed deepest first only if empty (`rmdir` semantics); a non-empty one is left alone and forgotten.

= Consequences
- Adopting an existing file into the repo is a separate action (`mdot adopt`, Phase 2).
- No automatic repair of drift. This can be revisited if it proves annoying.
- State must record the directories mdot created.
]
