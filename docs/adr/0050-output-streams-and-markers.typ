#import "../template.typ": adr

#adr(number: 50, title: [Output streams and diagnostic markers], status: [Accepted], date: [2026-10-26])[
= Context
No ADR decides where mdot's messages go (stdout or stderr) or how a reader tells an error from
normal output. The replacement for `print` (ADR 0013), the plan and apply format, and the logging
library (ADR 0036) all depend on it.

What exists: `src/bin/mdot.rs` has stand-ins for spdlog that print `[info ]: ...` to stdout and
`[error]: ...` to stderr, and conflicts go through the error one. The C++ CLI used exit codes 0 ok /
2 conflict / 3 error; the Rust port currently returns 1 for both conflicts and errors. ADR 0029
fixes exit code 3 and the message for an apply that fails partway. The plan sketch in `design.typ`
shows a conflict inside the plan.

A conflict is not an error: it is a valid result of planning ("this would clash"), while an error
means mdot could not do its job (a spec failed to load, a write failed).

= Options
- *Markers:*
  - A. A lowercase word prefix, as in git, cargo and rustc: `error: ...`, `warning: ...`.
  - B. Brackets on every line, as `mdot.rs` does now: `[info ]: ...`, `[error]: ...`.
  - C. Symbols in the plan's column: `! conflict ...`, `x error ...`.
- *Conflicts:* on stdout as part of the plan, or on stderr with the errors.
- *Summary:* one for the whole run, or one per spec (deferred, see Open).

= Decision
From the author:

- *Streams:* the plan and `mdot.print` go to stdout. Errors, conflicts and warnings go to stderr.
  Warnings go to stderr because that is what other command-line tools do.
- *Option A.* Diagnostics start with a lowercase word: `error:`, `conflict:` or `warning:`.
  Normal output has no prefix.
- *`conflict:` is its own word,* not a kind of `error:`.
- *Color:* `error:` and `conflict:` are red, `warning:` is yellow. (Red errors and yellow warnings
  were Claude's example; the author added red for conflicts.)
- *Follow-up lines* such as `hint:` and `note:` under a diagnostic are wanted, but not in the first
  version. They come when mdot is close to finished.
- *Plan layout is not part of this ADR.* It belongs to the plan and apply format item.

Claude's reasons for A, which the author adopted without giving a reason of their own: it is the
convention of tools the author uses daily, it works without color, it can be searched with `grep`,
the plan stays free of prefixes, and clap's own errors already look like this.

Accepted additions proposed by Claude:

- *Format:* `<word>: <message>`. A message about a file starts with its path or `file:line`, as in
  `error: specs/foo/spec.lua:3: attempt to call a nil value`.
- *Color only in a terminal:* each stream is colored only when that stream is a terminal, so piped
  or redirected output has no escape codes.
- *`NO_COLOR`:* when the `NO_COLOR` environment variable is set and not empty, there is no color
  (the convention from no-color.org).
- *`design.typ`* states the streams, the words and the colors in its Output section.

Examples (stream on the left; the plan layout shown is not decided):

```
1 | waybar
1 |   + link  ~/.config/waybar -> configs/waybar
2 | conflict: ~/.config/foot/foot.ini: exists and is not managed
2 | warning: ~/.config/hyprshot: directory not empty, left in place
2 | error: specs/foo/spec.lua:3: attempt to call a nil value
```

= Consequences
- `mdot plan > plan.txt` gets the plan and any `mdot.print` lines, but not the conflicts, warnings
  or errors. A script still sees a conflict through the exit code.
- `mdot.print` output is mixed into a redirected plan.
- The `[info ]` and `[error]` stand-ins in `mdot.rs` do not match this ADR, and the logging library
  (ADR 0036) must be able to produce this format.

= Open
- *Plan and apply format:* one summary for the run or one per spec; whether a conflict line appears
  under its spec or after the plan; whether conflict details should also reach a redirected plan.
- Whether a spec can choose a stream (`mdot.stdout.print` / `mdot.stderr.print`); this stays with
  the replacement for `print`.
- Exit code 2 is both clap's code for a usage error and mdot's code for a conflict.
- Whether loading stops at the first broken spec or reports every one.
- When the `hint:` / `note:` lines come, and their exact form.
]
