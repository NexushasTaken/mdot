#import "../template.typ": adr

#adr(number: 28, title: [Only packages mdot installed are removable; the record is mdot's own], status: [Proposed], date: [2026-10-12])[
= Context
ADR 0027 installs every package in the installed set as _explicit_ and says mdot's own state, not
pacman's orphan tracking, decides what is removable. It does not say what that state records, or
what happens to a package that was already installed before mdot saw it.

That case matters because of the philosophy that nothing destructive happens without consent. If a
user installed `git` by hand and later adds `requires { "git" }` and then drops it again, uninstalling
`git` removes something mdot never installed. Changing that package's install reason in pacman's
database to mark it would also break the rule: it edits a package mdot does not own.

= Options
- Treat every package in a spec as owned. Dropping the spec uninstalls hand-installed packages.
  Rejected.
- Mark ownership in pacman (install reason, or a hook). Edits packages mdot did not install, and the
  information would live outside mdot. Rejected.
- Record ownership in mdot's state, and only for packages that mdot itself installed. Chosen.

= Decision
Each `Package` resource (ADR 0009) records `installed_by_mdot`.

- At apply, a desired package that is not installed is installed, and recorded with
  `installed_by_mdot = true`.
- A desired package that is already installed is a no-op, recorded with `installed_by_mdot = false`
  (present, not owned). Planning shows it as `present`.
- A package is a removal candidate only if it is recorded with `installed_by_mdot = true` and no
  reachable spec still names it (through `package` or `requires`, ADR 0027). Candidates follow the
  recorded `on_remove.package` policy (ADR 0011, default `ask`) and appear in the `apply` plan.
  There is no separate uninstall command.
- Removal runs `pacman -R`, not `-Rns`. If a package outside mdot depends on it, pacman refuses and
  mdot reports a failure. It does not retry with force.
- If the user removes a recorded package by hand, `status` reports drift. If a later `apply`
  installs it again, it is recorded as `installed_by_mdot = true`, because mdot installed that
  copy.
- If the state file is lost, every package looks pre-existing, so nothing is proposed for removal.
  The failure direction is "keep".

*Referrers are derived, not stored.* Which specs or hosts need a package comes from the reachable
specs (the reverse index in ADR 0027), so it is not part of state. The words _implicit_ and
_explicit_ are not used for this, so they do not clash with pacman's install reasons. A listing,
for example:

```
waybar   required by: host:nexos            not installed
dunst    required by: hyprland              installed (by mdot)
fzf      required by: hyprland, host:nexos  installed (pre-existing)
```

Where this view lives is not decided. It could extend `mdot why` (ADR 0027) or `mdot specs`.

= Consequences
- Extends ADR 0027: it fixes what the `Package` record holds. The recorded set is the only source of
  removal decisions, so the `PackageProvider` needs `query`, `install` and `remove` only.
- Answers the first, second and third unknowns of RQ2 on paper (pre-existing packages, a package
  owned by one spec and required by another, hand-installed packages). Experiment S3 tests this.
  AUR packages from custom repos stay open.
- Side effect: mdot-installed packages show up in `pacman -Qe`. That is accepted.
- Stale text, to be updated separately: the `Package` row of the resource table (ADR 0009 and
  `design.typ`), and the "Package semantics" paragraph and `PackageProvider` interface in
  `design.typ`, which still describe `--asdeps`, `Reason` and `set_reason`.
- Phase 5, not Phase 1. Phase 1 only needs the state format to have room for a package list.
- Open: whether a user can later promote a `present` package to owned (for example "I want mdot to
  remove it when I drop the spec"). Not designed, and not needed for the first version.
]
