#import "../template.typ": adr

#adr(number: 59, title: [Logging uses `tracing`; state files use `serde_json`], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0036 left two library choices open: what replaces spdlog/fmt for logging, and which JSON
library replaces nlohmann-json for state files. `fmt` needs no replacement, since formatting is
built into Rust (`format!`, `println!`, `eprintln!`).

ADR 0050 decides user-facing output: the plan and `mdot.print` on stdout; `error:`, `conflict:` and
`warning:` lines on stderr, colored only in a terminal, no color when `NO_COLOR` is set. It says
the logging library must be able to produce this format.

Both logging libraries were tried in a scratch crate on 2026-10-26 (`tracing` 0.1.44,
`tracing-subscriber` 0.3.23, `log` 0.4.34, `env_logger` 0.11.11). Findings:

#table(
  columns: (auto, 1fr, 1fr),
  [], [`log` + `env_logger`], [`tracing` + `tracing-subscriber`],
  [Downloads (crates.io)], [1.43 B / 603 M], [973 M / 695 M],
  [Context per line], [none; pass it to every call], [spans: every line inside a span carries its
    name and fields],
  [Indented or grouped output], [none built in; a thread-local depth counter can fake it],
    [add-on layers `tracing-tree` (indented) and `tracing-forest` (tree with timings)],
  [Filter by context], [module, or a regex on the message text only], [module, span, or span field
    (`info,[bake{cake=carrot}]=debug` worked)],
  [Default stream], [stderr], [stdout; `.with_writer(std::io::stderr)` changes it],
  [Color when piped], [off automatically], [on; `NO_COLOR=1` turns it off],
  [`RUST_LOG` unset], [only ERROR lines], [only ERROR lines (with the `env-filter` feature)],
  [Crates pulled in], [19], [27],
)

Also seen with `tracing`: `let _ = span.entered()` leaves the span at once without a warning (the
guard must be bound to a name such as `_guard`); writing to a closed pipe prints a
`Broken pipe` message per event to stderr but does not crash.

`tracing` has no `conflict` level, and its default format is `ERROR target: message`, not ADR
0050's `error: message`. A second test wrote a custom formatter (about 25 lines implementing
`tracing_subscriber`'s `FormatEvent`): ERROR printed as `error:`, WARN as `warning:`, an event with
`target: "conflict"` as `conflict:`, and INFO with no prefix. That output matched ADR 0050. With
that one subscriber, `RUST_LOG` filtered the user's output too:

#table(
  columns: (auto, 1fr),
  [`RUST_LOG`], [What was printed],
  [unset], [everything],
  [`error`], [only the conflict and the error; the plan-style lines were gone],
  [`off`, or set but empty], [nothing, errors included],
  [`debug,conflict=off`], [everything except the conflict],
)

Field values (`cake="rye"`) were still colored when piped.

For JSON, `serde` with `serde_json` is the common choice in Rust: derive `Serialize` and
`Deserialize` on a struct to get both directions. No alternative was tested.

= Options
- *Logging:* `log` + `env_logger` (more popular, simpler, CLI-friendly defaults) or `tracing` +
  `tracing-subscriber` (spans, context filters, tree output).
- *Where user output comes from* (options proposed by Claude):
  - A. mdot's own print functions for the plan and ADR 0050's diagnostics; `tracing` only for
    debug logs.
  - B. `tracing` for everything, with two separate outputs: one for user output that is always on,
    and one for debug logs that the environment variable filters.
- *JSON:* `serde_json`; not compared with alternatives.

= Decision
From the author:
- *Logging* uses `tracing` with `tracing-subscriber`, chosen over `log` + `env_logger` after the
  tests above. The author had asked for grouped and indented output during the research, which
  only `tracing` offers; the author did not state a reason beyond the choice.
- *Option B:* user output (the plan and ADR 0050's `error:`, `conflict:` and `warning:` lines) also
  goes through `tracing`, with a custom format matching ADR 0050. Claude recommended A, because
  with A a log setting can never hide an error; the author chose B.
- *State files* use `serde` with `serde_json`.

Part of option B as Claude proposed it, and so accepted with it:
- *User output and debug logs are separate outputs.* The environment variable filters only the
  debug output. The user output is always on, so no log setting hides the plan, a conflict or an
  error (the tests above show what happens with a single output).

Accepted additions proposed by Claude:
- *Debug logs go to stderr,* because stdout holds the plan and `mdot.print` (ADR 0050).
- *The default debug level is set explicitly in `main`,* because with `RUST_LOG` unset only ERROR
  lines appear (seen in the tests). Which level is Open.
- *Plain `fmt` output for debug logs first.* `tracing-tree` or similar may come later; switching
  only changes the subscriber setup in `main`, not the logging calls.

= Consequences
- ADR 0050's "the logging library must be able to produce this format" applies: mdot needs its own
  `FormatEvent` for the user output.
- The color setup must follow ADR 0050's rules (color only when the stream is a terminal, none
  with `NO_COLOR`), including the field values, which the default field formatter colors even when
  piped.
- The `[info ]` / `[error]` stand-ins in `src/bin/mdot.rs` are replaced by `tracing` calls.
- Dependencies are added only when code needs them (ADR 0036): `tracing` and `tracing-subscriber`
  (feature `env-filter`) with the first log call, `serde` (feature `derive`) and `serde_json` with
  the state file.

= Open
- *How the two outputs are separated.* Not tested: tracing-subscriber's per-output filters, or
  another way. The test above used a single subscriber.
- *How the plan reaches stdout and diagnostics reach stderr* within the user output (ADR 0050).
  Not tested.
- *How a conflict is marked,* since `tracing` has no `conflict` level. The test used
  `target: "conflict"`; that was a test choice, not a decision.
- Whether `mdot.print` goes through `tracing` too.
- The default debug level when the environment variable is unset.
- The environment variable's name: `RUST_LOG` or an mdot-specific one such as `MDOT_LOG`.
]
