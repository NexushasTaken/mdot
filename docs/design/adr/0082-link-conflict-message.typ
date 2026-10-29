#import "../template.typ": adr

#adr(number: 82, title: [A link conflict says what is there and whether mdot made it], status: [Accepted], date: [2026-10-29])[
= Context
The *Conflicts* paragraph in `design.typ`'s 3-way diff section still showed the format from before
ADR 0050:

```
error: hypr: cannot link ~/.config/hypr
  expected: missing, or symlink to specs/hypr/config
  found:    symlink to ~/old-hypr
```

and said each error names the spec, `src`, `dst` and what was found, and that the report adds that
a resource *drifted* when state says mdot created it. Since then:

- ADR 0050: a diagnostic is one line, `<word>: <message>`, starting with the path; `conflict:` is
  its own word; `hint:` / `note:` follow-up lines are not in the first version.
- ADR 0051 and ADR 0052: the spec's name is the heading, and the conflicting resource's `!` line
  shows `dst -> src` right above its `conflict:` line.
- ADR 0051: desired, recorded and live are shown at `-v=2` (form open).
- No ADR words the conflict message itself; the only example is `exists and is not managed`.

So the old `expected:` line repeats the `!` line, and the `found:` line and the drift note have no
place. ADR 0030 has three conflict rows for links:

#table(
  columns: 5,
  [*Row*], [*desired*], [*recorded*], [*live*], [*Meaning*],
  [1], [yes], [no], [anything else], [something not mdot's is in the way],
  [2], [yes], [yes], [anything else], [mdot made it and it was changed (drift)],
  [3], [no], [yes], [anything else], [mdot made it, it was changed, and the spec is gone],
)

= Options
- *A.* A fixed-shape message: `<what is there>, <who owns it>`.
- *B.* Only make the example a one-line `conflict:` and leave the wording per case open.

= Decision
From the author:

- *Option A.* A link conflict message is `<what is there>, <who owns it>`. The author's reason: it
  is self-descriptive and tells the user what is happening.

Accepted additions proposed by Claude:

+ *`<what is there>`* is one of `regular file`, `directory`, `symlink to <target>`, or
  `special file` (fifo, socket, device, anything else).
+ *`<who owns it>`* is `not managed by mdot` for row 1, and `changed since mdot made it` for rows 2
  and 3 (both are drift).
+ *Symlink target:* shown exactly as stored in the link (the raw `readlink` value), not resolved or
  shortened.
+ *Scope:* links only. Other kinds (copies, downloads) word their conflicts when they are designed.
+ *`design.typ`* replaces the stale example and prose in the 3-way diff section, and its Output
  example uses `regular file, not managed by mdot`.

```
hypr
  ! link  ~/.config/hypr -> config
conflict: ~/.config/hypr: symlink to ~/old-hypr, not managed by mdot           (row 1)
conflict: ~/.config/hypr: symlink to ~/old-hypr, changed since mdot made it    (rows 2, 3)
```

= Consequences
- What was expected is not repeated: the `!` line already shows it.
- Drift needs no extra line: it is the `<who owns it>` part of the same message.
- ADRs 0050, 0051 and 0052 are not edited; their `exists and is not managed` examples were
  illustrations, and `design.typ` follows this ADR.

= Open
- Conflict wording for kinds other than links.
- The form of the `-v=2` desired / recorded / live lines (ADR 0051).
]
