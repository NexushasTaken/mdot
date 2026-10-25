#import "../template.typ": adr

#adr(number: 40, title: [The `host` global becomes `mdot.os.hostname`], status: [Accepted], date: [2026-10-25])[
= Context
`design.typ` lists a read-only global `host = { name = <hostname> }`. It came from ADR 0017
(`enabled(host.name == …)`), which ADR 0019 superseded: per-host choices now live in
`hosts/<hostname>.lua`, and no Phase 1 clause reads `host`. ADR 0038 puts what mdot hands to Lua in
one `mdot` table and left open whether `host` becomes a member of it, and left `mdot.os` undesigned.
`--host <name>` makes `plan` and `status` load `hosts/<name>.lua` instead (ADR 0019). ADR 0013 left
"Host and OS info" open.

Base `vars` is `mdot.vars` after `config.lua` alone (ADR 0038), and the git clean filter evaluates
markers with it (ADR 0037).

= Options
- *Where it lives:* keep `host` as a separate global, move it into `mdot`, or drop it.
- *Shape:* `mdot.host = { name }`, a string `mdot.host`, or `mdot.os.hostname`.
- *Value under `--host`:* the real machine's name, or the name of the host being previewed.
- *Specs reading it:* allow it, discourage it in the docs, or forbid it.
- *`config.lua` reading it:* hide `mdot.os` from `config.lua`, or allow it.

= Decision
From the author:

- *`host` moves into `mdot`*, "same as vim", *as `mdot.os.hostname`*.
- *Under `--host laptop`, `mdot.os.hostname` is `"laptop"`.* The author's reason: the purpose of
  `--host` is to pretend the current host is a different one.
- *Specs may read it.* The author's reason: every context in `mdot.*` is shared. A spec can
  therefore branch on the hostname, so a per-host difference may live in a spec as well as in the
  host file.
- *`config.lua` may read it too.* A hostname branch in `config.lua` makes base `vars` differ per
  machine, so the clean filter commits different canonical values on different machines. That is
  the user's fault (ADR 0039).
- *For now `mdot.os` holds only `hostname`.*

Accepted additions proposed by Claude:

- *Definition:* `mdot.os.hostname` is exactly the `<name>` mdot used to select `hosts/<name>.lua`:
  the real hostname, or the `--host` value.
- *Read-only:* writing to `mdot.os` from any file is an error naming the file.
- *Unknown fields:* reading a field `mdot.os` does not have (a typo such as `mdot.os.hostnme`) is an
  error naming the field, instead of a silent `nil`.
- *The `host` global is removed.*
- *`design.typ` warns* that a hostname branch in `config.lua` makes base `vars` differ per machine.

= Consequences
- Closes ADR 0038's open item on `host`, and narrows its `mdot.os` item: `hostname` is designed,
  other fields (OS name, architecture, …) are designed when a real spec needs one. ADR 0038 itself
  is unchanged.
- Answers another part of ADR 0013's open "Host and OS info"; the rest stays open.
- Everything mdot hands to Lua now lives in `mdot`.
- `plan --host <name>` evaluates hostname branches as that host would.
]
