#import "../template.typ": adr

#adr(number: 78, title: [`mdot.print` replaces `print`; lines are written when called], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0013 allowed plain `print` in the sandbox "for now", until mdot had its own output function.
Settled before this ADR: the function is `mdot.print`, each line is tagged with `file:line`
(`todo.typ`), and it goes to stdout (ADR 0050). Left open: whether a spec can choose a stream
(ADR 0050), and where its lines appear relative to the plan (ADR 0051).

Facts that shaped it:
- Spec code runs while specs load, and loading comes before planning.
- `apply` plans without printing the plan, then asks `apply? [y/N]` (ADR 0068).
- `design.typ` lists the `mdot` global's members as `os`, `dirs` and `vars`, and says any other
  member is an error. That rule did not allow `mdot.print`.

= Options
- *Streams:* one fixed stream, or a choice (`mdot.stdout.print` / `mdot.stderr.print`).
- *Position:* write each line the moment it is called, or hold the lines back and show each one under
  its spec's heading in the plan.
- *Plain `print`:* keep it in the sandbox, or remove it.

= Decision
From the author:
- *`mdot.print` is the only print function.* It writes to stdout and tags each line with
  `file:line`.
- *No stream choice.* There is no `mdot.stdout.print` or `mdot.stderr.print`; the author found them
  unnecessary.
- *A line is written the moment `mdot.print` is called.* The author saw no reason to put it
  anywhere else. Because specs load before planning, all print lines come before the plan in
  `mdot plan`, and before the question in `mdot apply`.
- *Plain `print` is removed from the sandbox,* since mdot already provides it. Calling it fails like
  any other name outside the allowlist. This replaces ADR 0013's "`print` is allowed for now".
- *`print` is a member of the `mdot` global,* next to `os`, `dirs` and `vars`.

Accepted additions proposed by Claude:
+ *Line format:* `<path>:<line>: <text>`, the path relative to the repo, as in ADR 0050's messages
  about a file.
+ *Arguments as in Lua's `print`:* any number of values, each converted with `tostring`, joined by a
  tab, ending with a newline.
+ *Available in every file:* specs, `config.lua` and host files.
+ *Shown at every `--verbose` level* (ADR 0051), like errors.
+ *Plain text:* never colored and no `word:` prefix; those belong to diagnostics (ADR 0050).

Example (stream on the left):

```
1 | specs/foot/spec.lua:4: font	Hack Nerd Font
1 | waybar
1 |   + link  ~/.config/waybar -> config
1 |
1 | Plan: 1 to create.
```

= Consequences
- Closes the stream question left open in ADR 0050 and the print position left open in ADR 0051.
- `mdot plan > plan.txt` contains the print lines before the plan (ADR 0050 already noted the mixing);
  the `file:line` tag tells them apart.
- When a spec prints and then fails to load, its print lines appear before the `error:` line.
- A spec cannot write to stderr or produce a `warning:` line.
- Existing specs that call `print` must switch to `mdot.print`.
]
