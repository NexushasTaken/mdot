#import "../template.typ": adr

#adr(number: 20, title: [`dst` expands only a leading `~`], status: [Accepted], date: [2026-10-11])[
= Context
ADR 0015 left open whether `dst` may use `$XDG_CONFIG_HOME` or other variables. The old comtrya setup
used `user.config_dir`. Expanding variables inside strings makes `dst` depend on the environment.

= Decision
Only a leading `~` is expanded, to `$HOME`. Implicit specs link to `~/.config/<name>`, hardcoded. A
`$` anywhere in `dst` is a load error, so a typo cannot create a directory literally named
`$XDG_CONFIG_HOME`.

= Consequences
- A user who sets `XDG_CONFIG_HOME` elsewhere is not followed by implicit specs.
- If it is needed later, add a named context value such as `xdg.config` rather than string expansion,
  so it is explicit and visible in `plan`.
]
