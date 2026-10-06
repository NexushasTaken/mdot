#import "../template.typ": adr

#adr(number: 6, title: [Per-host variation via `enabled(<lua expr>)`], status: [Accepted], date: [2026-10-06])[
= Context
The author has several machine roles (e.g. `nexos.yaml`, `tablet.yaml`). Options: `enabled`
expression per spec, host files that select specs, or both.

= Decision
Each spec may declare `enabled(<boolean expression>)` over `host`, `os`, `vars`, `env()`. Default is
enabled. An enabled spec depending on a disabled one is an error.

= Consequences
- No separate host-file concept; host logic lives with the spec it affects.
- Whether `enabled` should accept a lazily evaluated function is open (RQ5).
]
