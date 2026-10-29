#import "../template.typ": adr

#adr(number: 67, title: [Every missing spec or host name exits with 2], status: [Accepted], date: [2026-10-27])[
= Context
ADR 0053 gives 1 when mdot finished its checks and a rule says no, and 2 when it could not do its
job (a usage error, an unreadable file, a Lua error). ADR 0065 left open the code for an unknown
`<spec-name>` argument (`mdot specs waybr`), and gave 1 to an unknown name in `depends` (its
addition 8). `design.typ` makes a `--host` with no `hosts/<name>.lua` an error that lists the files
in `hosts/`, without a code. clap only checks the shape of the command line, so mdot itself finds
these names missing.

= Options
- *1:* a rule says no (the name must exist).
- *2:* mdot could not do its job.
- *Split:* 2 for names on the command line, 1 for names in `depends` (the spec file itself loaded).

= Decision
From the author:

- *Every missing name is 2:* `mdot specs <unknown name>`, `--host <name>` with no
  `hosts/<name>.lua`, and `depends("<unknown name>")`. The author's reason: each is like reading a
  file that does not exist, which ADR 0053 already makes a 2.
- *The split was rejected,* so `depends` is 2 as well. This supersedes the 1 for an unknown name in
  `depends` in ADR 0065 (addition 8). A cycle stays 1.

Accepted additions proposed by Claude (accepted as a whole, without reasons of their own):

- *Names only:* this covers spec names and host names. A missing `src` path in `file.link` is not
  covered and keeps what ADR 0021 and ADR 0053 give it.
- *An existing but unreached spec:* `mdot specs rofi`, where `specs/rofi/` exists but the host does
  not reach it, exits with 0; it is shown as not reached (ADR 0065).
- *Partial output:* `specs` still prints the error and then what loaded (ADR 0065); only the code is
  2.
- *Recording:* ADR 0065's index status notes the superseded code, and `design.typ`'s Exit codes
  paragraph lists a missing spec or host name under 2.

#table(
  columns: 2,
  [*Case*], [*Code*],
  [`mdot specs waybr` (no `specs/waybr/`)], [2],
  [`mdot plan --host typo` (no `hosts/typo.lua`)], [2],
  [`depends("waybr")` (no `specs/waybr/`)], [2],
  [`mdot specs rofi` (exists, not reached)], [0],
  [a `depends` cycle], [1],
)

= Consequences
- Closes ADR 0065's last open item that belongs to `specs` (the code for an unknown `<spec-name>`).
- A typo in a name, on the command line or in a spec, gives the same code.
]
