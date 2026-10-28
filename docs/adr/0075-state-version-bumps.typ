#import "../template.typ": adr

#adr(number: 75, title: [Every `state.json` format change bumps `version`; an unknown field is an error], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0060 settled what mdot does with a `version` it meets: newer is refused ("upgrade mdot"), older
is migrated in memory and saved on the next write. It left open what a migration does, and with it
which format changes count as a new version. An unknown `kind` is already a hard error, since
ignoring it would drop the record on the next write.

Constraints:
- ADR 0060: `version` is 1. A newer file is refused; an older one is migrated one version at a time.
- ADR 0062: `version` stayed 1 when `repo` was added, since nothing had shipped. Only `apply` writes
  `state.json`.
- ADR 0030: with no record, a live link that already points to the desired `src` is adopted with no
  change on disk. So in Phase 1 (links only), losing `state.json` loses only the records of links
  whose spec was since removed (they are never deleted) and `created_dirs` (never cleaned up).
- The author is the first user: their own repo has a `state.json` before any release.

= Options
+ *Every format change bumps `version`;* an unknown field is an error. An added optional field is a
  new version with a small migration that fills in its default. Chosen.
+ *Only a breaking change bumps;* unknown fields are ignored. Each change needs a judgment of whether
  it breaks, and an older mdot drops a newer field on its next write.
+ *Like 1, but the "migration" is "delete `state.json` and re-run `apply`".* Relies on the ADR 0030
  adopt case. Taken in a narrower form as addition 3.

= Decision
From the author:
- *Option 1:* every change to the `state.json` format bumps `version`, and an unknown field is an
  error. The author took this on Claude's recommendation (it needs no judgment of whether a change
  breaks, and matches the unknown-`kind` rule).
- *Keep format changes rare during development.* Not a strict rule before the first release.

Accepted additions proposed by Claude (reasons are Claude's):
+ *An unknown field is an error at any level:* top level or inside a record. Exit 2, naming the
  field. Same reason as an unknown `kind`: ignoring it would drop it on the next write.
+ *A missing required field is an error* (exit 2). mdot did not write that file, or it is damaged;
  guessing a default would hide that.
+ *Before the first release, a bump may ship without a migration.* mdot then refuses the older file
  and tells the user to delete `state.json` and re-run `apply`. With only the author as a user, this
  costs the losses listed under Context, once.
+ *`plan` migrates in memory only;* `apply` saves the migrated file. `plan` stays read-only for
  `state.json` (ADR 0062).

```
load_state(path):
  if file missing:                     return empty state
  parse JSON, else:                    error, exit 2
  v = field "version", else:           error, exit 2
  if v >  CURRENT:                     error "upgrade mdot", exit 2
  if v <  CURRENT:
    if no migration from v:            error "delete state.json and re-run apply", exit 2
                                       # pre-release only
    migrate v -> v+1 -> ... -> CURRENT, in memory
  unknown field anywhere:              error naming it, exit 2
  required field missing:              error naming it, exit 2
  return state                         # only apply writes it back
```

= Consequences
- Whether a version bump is needed never takes a judgment call: any change to the format needs one.
- Each released bump costs one migration function, even if all it does is fill in a default.
- A hand-edited typo in `state.json` is caught instead of being dropped silently.
- After the first release, a bump without a migration is no longer allowed.

= Open
- *Keeping the old file* when a migrated one overwrites it (for example, to allow a downgrade).
- *Generation records* (Phase 2): whether old snapshots in `generations/` are migrated too.
]
