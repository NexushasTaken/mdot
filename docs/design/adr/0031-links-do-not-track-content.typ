#import "../template.typ": adr

#adr(number: 31, title: [mdot does not track linked content; `status` shows only mdot's resources], status: [Accepted], date: [2026-10-23])[
= Context
ADR 0009 (Proposed) said that for a `Link`, mdot owns only the link's existence and target, that
content history belongs to git, and that `mdot status` shows both. `design.typ` had `mdot status`
print `git status --short` of the repo next to the resource diff.

The author did not see why git belonged in that part of the design. A link makes `dst` a symlink
into the repo, so an edit through `dst` edits the repo file itself; there is no second copy that can
drift. For a link, `state.json` records `dst` and `src`, which covers everything the link table in
ADR 0030 compares.

= Options
- *What `mdot status` shows.* Only mdot's own resource diff; or the resource diff plus
  `git status --short` of the repo.
- *The repo.* It must be a git repository; or git is the user's choice.

= Decision
- *mdot does not track the content of linked files.* For a link, mdot owns whether it exists and
  where it points. The author's reasoning: each clause tracks its own resource, and plan/apply know
  whether desired equals live by comparing against the recorded state, not by looking at the edited
  files.
- *An edit made through a link is never reported* by `plan` or `status`. It is a change to the repo,
  not drift. A user who wants content history keeps the repo in git and uses git for it.
- *`mdot status` shows only mdot's own resource diff.* It does not run or print `git status`.
- *The repo does not have to be a git repository.* mdot is like any other dotfile manager here;
  using git is the user's choice.

= Consequences
- Replaces the link/git ownership part of ADR 0009, which stays Proposed for the resource model only.
- `mdot status` and `plan` need no git for links.
- RQ3 no longer asks whether `status` plus `git status` makes the split obvious. It asks whether
  users understand that edits through a link are not reported.
- Copy-like kinds (`Download`, `Render`, `SysFile`) are unaffected: they write regular files, so
  their content is compared as before.

= Open
- What generations and rollback do in a repo that is not a git repository. ADR 0010 records a commit
  SHA and rolls back through a git worktree. Not decided here; it belongs to ADR 0010 (Phase 2).
]
