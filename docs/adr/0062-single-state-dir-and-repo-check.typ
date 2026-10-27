#import "../template.typ": adr

#adr(number: 62, title: [One state directory; the stored repo path is checked on every run], status: [Accepted], date: [2026-10-27])[
= Context
`design.typ` (State and generations) and ADR 0010 put state in `$XDG_STATE_HOME/mdot/<repo-id>/`,
with the repo-id a hash of the repo's absolute path. The todo list asked whether moving the repo,
which changes the hash and loses the state, should be accepted or changed.

Facts that shaped it:
- `design.typ`: the repo root is `--repo <dir>`, else `$PWD` if it contains `specs/`.
- ADR 0054: a link's ID is `link:<dst>`; the repo path is not part of it.
- ADR 0060: records store absolute `src`; the symlinks on disk hold that string.
- `planner.typ`: a link's live value is its `readlink` string, so a dangling link still compares.
- ADR 0030: desired `src` ≠ recorded `src` with live = recorded is *update*; a record with no desired
  side and live = recorded is *delete*.

With a repo-id, a moved repo finds empty state, and every old link becomes an unrecorded dangling
symlink, which is a conflict. A path hash can also change without a move: ADR 0056-style lexical paths
do not resolve symlinks, so reaching the repo through a symlinked directory gives another hash.

= Options
*Where state lives:*
+ *Per repo-id, hash of the lexical path.* Considered first; lexical was preferred over a resolved
  (`realpath`) path.
+ *Per repo-id, hash of the resolved path.*
+ *One state directory for mdot.* Chosen.

*What happens when the current repo is not the one the state belongs to:*
+ *Warn only,* then plan as usual.
+ *Refuse `apply`,* with an explicit way to proceed.
+ *Split on whether the old path still has `specs/`:* gone means moved (continue), present means a
  second repo (refuse).

= Decision
From the author:
- *mdot has one state directory, `$XDG_STATE_HOME/mdot/`,* with no `<repo-id>`. A repo-id assumes
  mdot supports several dotfile repos or moving the repo; it supports neither.
- *Moving or renaming the repo is not supported;* doing it is the user's responsibility.
- *The repo path is stored in state and compared on every run.* It is lexical: made absolute and
  normalized as in ADR 0056, symlinks not resolved.
- *If it differs, both `plan` and `apply`* first print the warning (state belongs to `<stored path>`,
  this repo is `<current path>`), then ask whether to continue. No stops; yes plans normally, and
  `apply` still asks its own confirmation (ADR 0052).
- *No flag for it,* because the case is rare. `--yes` does not answer this prompt.
- *If stdin is not a terminal,* mdot refuses: the warning, then exit 1 (ADR 0053).
- *After a successful `apply`,* the new path is stored, so the warning shows once per switch.

Accepted additions:
+ *The field is a top-level `"repo"`* in `state.json`. This ADR extends ADR 0060.
+ *`version` stays 1:* nothing has shipped, so no old file needs migrating.
+ *Missing state, or no `repo` field:* the current path is stored without a prompt.
+ *Only `apply` writes it.* Answering yes to `plan` does not store the new path, so `plan` keeps asking
  until an `apply` succeeds.
+ *The warning and the prompt go to stderr* (ADR 0050), *default answer No* (`[y/N]`).
+ *Layout:* `state.json`, `generations/` and `backups/` move up to `$XDG_STATE_HOME/mdot/`. This
  replaces the path in ADR 0010.

= Consequences
- A moved repo is not a supported operation, but after the prompt it plans as updates (ADR 0030):
  every link mdot made is relinked to the new path; links changed by hand are conflicts.
- Running mdot on a second repo plans a delete for every link of the first that is still mdot's
  (the symlinks are removed; files in the old repo are untouched), behind two prompts. Empty created
  directories go with them (ADR 0060).
- To try a second repo without touching the real setup, point `XDG_STATE_HOME` elsewhere, or delete
  `state.json`. No mdot feature is needed for that.
- Scripts that switch repos stop with exit 1 instead of acting.

= Open
- *Locking:* two `apply` runs at once. Next todo item.
- *The state directory on macOS and Windows.* `$XDG_STATE_HOME` is a Linux convention; which
  directory other OSes use is not decided.
- *Prompt mechanics* shared with ADR 0052 (Open): wording, how an answer is read.
]
