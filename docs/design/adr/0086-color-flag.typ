#import "../template.typ": adr

#adr(number: 86, title: [`--color <auto|always|never>`; the flag overrides `NO_COLOR`], status: [Accepted], date: [2026-10-29])[
= Context
`design.typ`'s global flags list `--color`, but no ADR says what it does.

What constrains it:

- ADR 0050: `error:` and `conflict:` are red, `warning:` is yellow. Each stream (stdout, stderr) is
  colored only when that stream is a terminal, and there is no color when the `NO_COLOR`
  environment variable is set and not empty.
- ADR 0078: `mdot.print` output is never colored.
- `design.typ` (Output): colors for the plan symbols (`+`, `!`, `=`) are open.
- ADR 0085: a flag is added only when it is wanted; `-q` was dropped on that rule.

no-color.org, the convention ADR 0050 follows, says in its FAQ: "User-level configuration files and
per-instance command-line arguments should override the `NO_COLOR` environment variable."

= Options
- *Precedence between the flag and `NO_COLOR`:*
  - A. The flag overrides `NO_COLOR`, as no-color.org says.
  - B. `NO_COLOR` overrides the flag: when it is set, `--color=always` does nothing, and one run
    gets color only with `NO_COLOR= mdot ...`.

= Decision
From the author:

- *`--color` is in Phase 1.*
- *Option A: the flag overrides `NO_COLOR`.* The author first chose B, then chose A to follow
  no-color.org once Claude pointed out its FAQ. The author's reason: it is the published
  convention. The author learned of no-color.org during this decision.

Accepted additions proposed by Claude:

- *Values:* `--color <when>`, where `<when>` is `auto`, `always` or `never` (the words git, cargo,
  ls and ripgrep use).
- *Default:* `auto`, which is ADR 0050's behavior unchanged, so a run without the flag behaves as
  before.
- *`always`* colors both streams even when they are not terminals, so
  `mdot plan --color=always | less -R` keeps its color.
- *`never`* gives no color on either stream.
- *Scope:* the flag controls only what ADR 0050 colors (the `error:`, `conflict:` and `warning:`
  words). `mdot.print` stays uncolored. Plan symbol colors stay open.
- *ADR 0050 is not edited.* This ADR adds the flag on top of it; `design.typ` states the rule in
  its Output section and global flags.

The rule, per stream:

```
when = value of --color, or "auto" when not given

for each stream (stdout, stderr):
    if when == "always": color = true
    if when == "never":  color = false
    if when == "auto":   color = stream is a terminal AND NO_COLOR is unset or empty
```

#table(
  columns: 4,
  [*Situation*], [*`auto`*], [*`always`*], [*`never`*],
  [`mdot plan` in a terminal], [colored], [colored], [plain],
  [`mdot plan | less -R`], [plain], [colored], [plain],
  [`NO_COLOR=1 mdot plan` in a terminal], [plain], [colored], [plain],
)

= Consequences
- Someone with `NO_COLOR` set in their shell gets color for one run with `--color=always`.
- `--color=always` writes escape codes into files and pipes; that is the user's request.
- One more global flag to parse, document and test.

= Open
- Whether clap's own usage errors follow `--color` (implementation detail).
- Colors for the plan symbols (already open in `design.typ`).
]
