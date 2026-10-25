#import "../template.typ": adr

#adr(number: 51, title: [Layout of `mdot plan` and the `--verbose` levels], status: [Accepted], date: [2026-10-26])[
= Context
`design.typ` had a sketch of `mdot plan`'s output that was never decided, and it did not follow
ADR 0050: it showed a conflict as `! conflict ...` inside the plan, while ADR 0050 makes conflicts
`conflict:` lines on stderr. The plan goes to stdout without prefixes (ADR 0050). The planner gives
each resource create, update, delete, no-op or conflict (ADR 0035). Command-line flags have no
matching `mdot.opt` option (ADR 0047).

Tested on 2026-10-26: Rust's stdout is always line-buffered (std wraps it in a `LineWriter`, also
when redirected) and stderr is unbuffered, so whole lines written to both appear in the terminal in
the order mdot writes them.

= Options
- *Unchanged resources:* hidden, shown, or controlled by a flag.
- *Conflict position:* under its spec's heading, or after all specs.
- *Verbosity flag* (tested with clap 4.6.7):
  - A. An optional number after a space (`-v 2`). `-v specs/nvim` is an error, because
    `specs/nvim` is read as the level.
  - B. An optional number attached with `=` (`-v=2`, `--verbose=2`). `-v 2` means level 1 and a
    spec path `2`.
  - C. A counted flag (`-v`, `-vv`). No ambiguity, but no numeric form.
- *Level 2:* explain each resource's action with desired / recorded / live; trace what mdot does
  (closer to logging, ADR 0036); or leave it reserved.
- *Paths:* as written in the spec, or expanded.

= Decision
From the author:

- *Grouping:* each spec's name is a heading with its resources under it. Specs come in dependency
  order.
- *Line order:* symbol, kind, `dst -> src`, then an optional detail in parentheses. `src` is shown as
  written in `spec.lua`. `dst` is shown as written, with `~` kept.
- *Symbols:* `+` create, `~` update, `-` delete (from the sketch), `=` no-op.
- *Conflicts* are listed under their spec's heading, after its other lines, not indented (they are
  ADR 0050 `conflict:` lines on stderr). That a redirected plan loses them is expected.
- *Summary:* one line for the whole run. `No changes.` when there is nothing to do.
- *Verbosity, option B:* `-v` / `--verbose` with an optional level attached with `=`. Plain `-v`
  is level 1.
  - 0 (default): changes and conflicts only. No-ops and specs with nothing to do are hidden.
  - 1: no-ops too, as `=` lines.
  - 2: also what is desired, recorded and live for each resource. The author called showing
    recorded and live a good suggestion.
  - Errors and warnings are shown at every level.

Accepted additions proposed by Claude:

- *The `-v 2` trap is known:* `-v 2` means level 1 and a spec path `2`. The level must be written
  `-v=2` or `--verbose=2`.
- *Levels above 2 act like 2.*
- *Order inside a spec:* resources in the order the spec declares them, then its conflicts.
- *Headings:* a spec's heading is shown when it has at least one line to show at the current level,
  so a spec with only a conflict gets its heading at level 0.
- *Alignment:* the kind is padded so the `dst` column lines up.
- *Summary wording:* `Plan: 1 to create, 1 to update, 1 to delete, 1 conflict.`, leaving out counts
  that are zero.
- *Display only:* showing `dst` with `~` does not decide how state stores the path; the resource ID
  question stays open (ADR 0034).
- *`design.typ`* shows this layout in place of the sketch.

Example at level 0 (stream on the left):

```
1 | waybar
1 |   + link  ~/.config/waybar -> config
1 | foot
1 |   + link  ~/.config/foot/colors.ini -> colors.ini
2 | conflict: ~/.config/foot/foot.ini: exists and is not managed
1 | hyprshot
1 |   - link  ~/.config/hyprshot  (spec removed; on_remove.files=remove)
1 |
1 | Plan: 2 to create, 1 to delete, 1 conflict.
```

At level 1, unchanged resources and specs with only unchanged resources appear too:

```
1 | nvim
1 |   = link  ~/.config/nvim -> config
```

= Consequences
- `mdot plan` with no flags shows only what would change, so a plan for dozens of up-to-date specs
  is a single `No changes.` line.
- `mdot plan > plan.txt` can contain a heading with nothing under it, when that spec has only a
  conflict.
- Level 2 needs the planner to keep the desired, recorded and live values for each resource, not only
  the action.

= Open
- The exact form of the level-2 desired / recorded / live lines. It depends on how the planner types
  its comparisons (ADR 0035, open).
- Colors for `+`, `~`, `-` and `=`.
- How the detail in parentheses is worded for each kind.
- Where `mdot.print` lines appear relative to the plan.
- The output of `mdot apply`.
]
