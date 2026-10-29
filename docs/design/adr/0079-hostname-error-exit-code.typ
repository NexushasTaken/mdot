#import "../template.typ": adr

#adr(number: 79, title: [Every hostname error exits with 2], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0070 defines three hostname errors and left their exit codes open: an uppercase name, an unsafe
name (empty, `.`, `..`, or containing `/` or `\`), and a hostname that is unavailable or empty.
ADR 0071 applies the same name rules to `preview <host>` and `specs --host`. ADR 0053 gives 1 when
mdot finished its checks and a rule says no, and 2 when it could not do its job; ADR 0067 gives 2
to every missing spec or host name. mdot (not clap) runs these checks at startup, before any host
file or spec is loaded.

#table(
  columns: 3,
  [*Case*], [*Example*], [*Name comes from*],
  [Uppercase name], [`mdot preview Laptop`, `specs --host Laptop`], [command line],
  [Unsafe name], [`preview ../x`, or a kernel hostname of `..`], [command line or the OS],
  [Hostname unavailable or empty], [macOS returns no `LocalHostName`], [the OS],
)

= Options
- *1:* a rule says no (for example "host names must be lowercase").
- *2:* mdot could not do its job.

= Decision
From the author:

- *All three errors exit with 2.* The author's reason: these cases are not mdot's fault but
  problems with the name it was given. (Claude noted that an uppercase `--host` comes from the
  command line, not the OS; the reason covers it as bad input.)

Claude's recommendation, adopted by the author: 2 for all three, because each fails before any
rule check runs; an uppercase argument is effectively a usage error, which is already 2; and
keeping 1 for rules about the repo and the machine (conflicts, duplicate `dst`) means a script
that sees 1 can look for a conflict.

```
startup:
    name = pick host name           # uppercase, unsafe, unavailable → 2
    load hosts/<name>.lua           # missing → 2 (ADR 0067)
    load specs, check rules         # broken rule → 1
    plan, find conflicts            # conflict → 1
```

Accepted additions proposed by Claude:

+ *Entry points:* the codes apply wherever ADR 0070's checks run: the real hostname (`plan`,
  `apply`, `specs`), `preview <host>` and `specs --host`.
+ *Warnings unchanged:* a name that only breaks the format (such as `my_box`) is still a warning
  and does not change the code (ADR 0053).
+ *Recording:* `design.typ`'s Exit codes paragraph lists a bad hostname under 2. ADR 0070 is not
  edited; its index status notes that this ADR closes its open item.

= Consequences
- Closes ADR 0070's open item (exit codes for the three errors).
- Every name problem, missing (ADR 0067) or bad (this ADR), exits with 2.
]
