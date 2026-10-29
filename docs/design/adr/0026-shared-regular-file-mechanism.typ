#import "../template.typ": adr

#adr(number: 26, title: [`file.copy` and `net.download` share one regular-file mechanism], status: [Accepted], date: [2026-10-11])[
= Context
ADR 0024 left three questions open that depend on `file.copy`: whether the stat record and
`mdot verify` are shared with it, whether `mode` is shared, and whether a `mode`-only change is an
update. ADR 0023 planned `file.copy` but did not design it.

`file.copy` and `net.download` differ only in where the bytes come from (the spec directory or a
URL). Both put a regular file at `dst`, and both can be edited by hand afterwards, so the cheap
"has it changed?" check is the same problem for each.

Whether `file.copy` is needed at all is unclear. The author's current setup (`~/dotfiles-v2`) has 27
`file.link` actions and no `file.copy`.

= Options
- Each clause has its own change detection, `verify` and `mode`. Duplicated rules, and `verify`
  would have to be explained per clause.
- One shared mechanism for every clause that writes a regular file. Chosen.
- For a `mode`-only change: ignore it, or treat it as an update. Ignoring it means a permission
  change in the spec is never applied. Update chosen.

= Decision
- Every clause that writes a regular file at `dst` uses the same mechanism from ADR 0024: the stat
  record (`size`, `mtime_ns`, `inode`), the `plan` decision table, the conflict rule, and `mdot verify`.
  Today that is `net.download`. `file.copy` joins it when it is designed. Only the source of the
  bytes differs.
- `mode` is a shared option. The wording `mode = "755"` is the same for every such clause.
- `mode` is part of the compared state:
  - The recorded state adds the file's permission bits, read from the same `stat` call as the rest.
  - The permission bits are part of "stat matches". A hand `chmod` therefore makes the stat differ,
    and `plan` reports a conflict, like any other hand edit.
  - New `plan` row: the file is recorded, the stat matches, the identity is unchanged, but the
    `mode` in the spec differs from the recorded one. Action: update, which only changes the
    permissions (`chmod`) and downloads or copies nothing.
  - `mode` is still not part of the identity (ADR 0024). It is compared through the stat, not
    through the hash.
- `file.copy` itself stays undesigned: its syntax, how it reads `src`, and when it is needed. It is
  designed when a real spec has a file that cannot be a link (for example a file that needs strict
  permissions, or one a sandboxed app cannot reach through a symlink).

= Consequences
- Resolves the three open items in ADR 0024 that concern `file.copy` and `mode`. ADR 0024 is kept
  unchanged as history; read its `mode` rule together with this ADR.
- `mdot verify` is a general command for regular files mdot wrote, not a download feature.
- A spec that has no `mode` does not enforce one. The recorded permission bits still count in the
  stat check, so a hand `chmod` is reported either way. This detail is not yet checked against an
  implementation.
- The `Download` row in the resource table of `design.typ` may later be renamed to cover both
  clauses. Left as it is until `file.copy` exists.
- Still open: which hash algorithms beyond `sha256` v1 supports (ADR 0024).
]
