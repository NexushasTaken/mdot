#import "../template.typ": adr

#adr(number: 47, title: [Command-line flags have no matching `mdot.opt` options; a flag wins], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0045 introduced `mdot.opt` (built-in default, then `config.lua`, then the host file) and left
open whether command-line flags get matching options. The global flags are `--repo`, `--host`,
`-v`/`-q` and `--color`; commands have `plan --diff`, `apply --yes`, `verify --all` and
`adopt --name`.

`mdot.opt` is known only after `config.lua` and the host file have run, so an error while loading
`config.lua` is printed before any option could apply. `--repo` finds the repo that holds
`config.lua`, and `--host` picks the host file that sets options, so neither can be an option.
`--yes` as an option would skip `apply`'s confirmation on every run on that machine.

= Options
- *Flags with matching options:* give some flags (`-v`/`-q`, `--color`, `--yes`) an `mdot.opt`
  option, or keep them on the command line only.
- *When both exist:* the flag wins, or the option wins.

= Decision
From the author:

- *`-v`/`-q`, `--color` and `--yes` are only available on the command line,* not in `config.lua`.
  The author's reason: it does not make sense to put them in `config.lua`.
- *A flag given on the command line takes priority.*
- *If one is needed in `config.lua` in the future, it is added then.*

Accepted additions proposed by Claude:

- *Every current flag is flag-only.* `--diff`, `--all` and `--name` too. `--repo` and `--host`
  cannot have options at all.
- *Precedence, for when a flag and an option ever both exist:* flag, then host file, then
  `config.lua`, then built-in default. `design.typ`'s `mdot.opt` section says so.
- *Adding an option later* takes a new ADR and a row in `design.typ`'s options table (ADR 0045).

= Consequences
- Closes ADR 0045's open item on flags. ADR 0045 is unchanged.
- Today `mdot.opt.color = …` is an unknown-option error, so adding an option later breaks no
  existing `config.lua`.
- An option for output (`color`, `verbose`) added later would still not apply to errors printed
  while `config.lua` loads.
]
