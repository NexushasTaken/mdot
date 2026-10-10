#import "../template.typ": adr

#adr(number: 4, title: [Auto-merged `specs/` folder with mirror roots], status: [Superseded by 0014], date: [2026-10-06])[
= Context
The earlier session used a single `config.lua`. Options discussed: single file, lazy.nvim-style
auto-merge folder, or a spec file next to its config files (`pkgs/<name>/spec.lua`).

= Decision
`config.lua` runs first (vars, defaults). Every `specs/**/*.lua` is loaded in its own environment
and returns one spec or a list; all are merged by `name`. Duplicate names are an error; order comes
from the `depends` graph, not file order. Deployed files live in mirror roots: `configs/` ↔
`dirs.home_config`, `home/` ↔ `dirs.home`, `data/` ↔ `dirs.home_data`, `system/etc/` ↔ `dirs.etc`.

= Consequences
- Resolves the earlier session's open question on mirror directory names.
- Repo file names should match target names; `config(..., { from = ... })` exists for exceptions.
- No override/extend mechanism for duplicate names yet (`research.typ`, Limitations).
]
