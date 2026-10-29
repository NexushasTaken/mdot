#import "../template.typ": adr

#adr(number: 76, title: [`mdot.opt` does not exist in Phase 1; ADR 0045 waits for its first option], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0045 defined `mdot.opt`: mdot's own settings, set by built-in default, then `config.lua`, then
the host file, with per-option "host-overridable" / "`config.lua` only" rules, errors for unknown
options and bad values, and read-only access from specs. Its only option, `on_remove`, was dropped
with the removal policy (ADR 0061), which left open whether an empty `mdot.opt` ships in Phase 1 or
the mechanism waits for its first option.

Facts at the time of the decision:
- `mdot.opt` has no options. Command-line flags never get a matching option (ADR 0047).
- The only candidate on file is the marker filter on/off default (ADR 0037, Open), a Phase 4 feature.
- Reading or writing an unknown member of the `mdot` global is already an error (ADR 0038, 0048).

= Options
- *A: ship an empty `mdot.opt`.* The table exists and all ADR 0045 rules are live; any assignment is
  an unknown-option error.
- *B: no `mdot.opt` in Phase 1.* Chosen.

= Decision
From the author:
- *B: `mdot.opt` does not exist in Phase 1.* No reason was given.

Accepted additions:
+ *Error in Phase 1:* using `mdot.opt` (read or write, in any file) is ADR 0048's generic
  unknown-member error. There is no special "not yet" message.
+ *ADR 0045 stays Accepted and stays the spec* for when the first option arrives. It is deferred, not
  superseded; its index status says so.
+ *`design.typ`:* the `mdot` member list and the isolation rule leave out `mdot.opt` for Phase 1
  (`config.lua` and host files may write only `mdot.vars`). The `mdot.opt` section stays, marked as
  not in Phase 1. The open question about an empty `mdot.opt` is removed.
+ *Adding `mdot.opt` later breaks no Phase 1 config,* because any use of it in Phase 1 was already an
  error.

= Consequences
- Closes ADR 0061's open item on an empty `mdot.opt`.
- Phase 1's `mdot` global has three members: `mdot.os`, `mdot.dirs`, `mdot.vars`.
- The first option, when one is designed, brings `mdot.opt` back with ADR 0045's rules and a row in
  `design.typ`'s option table.
]
