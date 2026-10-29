// TODO list of open items: anything still to decide or fix in the docs. Not part of the ADR
// index. Remove an item once the ADR or spec fix that closes it is written; move any follow-up
// that is still open into its own item first.

#set page(margin: 2cm)
#set text(size: 10pt)

= Phase 0 and 1: feature complete

Goal: Phase 0 and Phase 1 fully specified (plan A, 2026-10-27). Later phases stay sketches. When
designing the state record, check that a download record (ADR 0032) fits the same shape.

== Blocking Phase 1

== Inconsistencies and stale text in `design.typ`

== Gaps the implementation filled with a guess (2026-10-29)

The Rust implementation needed an answer where the spec has none. Each guess is Claude's, not
decided; the code marks it `TODO(design)` where one exists.

- [ ] *Relative `dst`* (`file.link("a", "foo")`, no `~/`, not absolute): the code makes it a load
  error, exit 2 (`src/loader.rs`, `expand_dst`).
- [ ] *A `dst` whose parent is a regular file:* the code plans it as a conflict, "a parent is not a
  directory" (`src/planner.rs`, `Observed::ParentNotDir`).
- [ ] *Plan detail wording* for adopt (`already linked; record only`), re-create (`removed by
  hand`), forget (`already gone`) and a delete whose spec is still reached (`clause removed`)
  (`src/output.rs`, `detail`).
- [ ] *Summary counts:* adopt is counted as an update and forget as a delete; the adopt line uses
  `~` and forget uses `-` (`src/output.rs`).
- [ ] *Apply line order:* ADR 0052 says apply uses plan's order, but steps run deletes first and
  creates last (ADR 0054). The code prints in execution order, with a new heading whenever the spec
  changes (`src/run.rs`, `apply`).
- [ ] *`config.lua` returning a value:* the code makes it an error, exit 2 (`src/loader.rs`).
- [ ] *Exit code of `mdot.vars` schema errors:* the code uses 1 (a rule), ADR 0039 does not say.
- [ ] *`-v=2` layout:* indented `desired:` / `recorded:` / `live:` lines under each resource
  (`src/output.rs`, `explain`).
- [ ] *`mdot.os.edition`:* `VARIANT_ID` from `/etc/os-release` on Linux, `nil` elsewhere; macOS
  `version` from `sw_vers -productVersion`; Windows `version` is `nil` (`src/facts.rs`).

== Later phases (not blocking)
- [ ] *A content diff* for content kinds (`file.copy`, `net.download`, `render` / `patch`): whether
  `plan` gets a way to show it, and in what form (ADR 0083).
- [ ] *Conflict wording for other kinds* (ADR 0082): copies, downloads.
- [ ] *Keeping the old `state.json`* when a migrated one overwrites it (ADR 0075).
- [ ] *Migrating generation records* (ADR 0075): whether old snapshots in `generations/` are
  migrated too. Phase 2.
- [ ] *Removing a package* (ADR 0028, ADR 0061): what it does. Phase 5.
- [ ] *A drift-only command* (ADR 0064): whether one returns in a later phase.
- [ ] *Authenticated downloads* (ADR 0074): how a private download gets credentials without
  putting them in the `url`.
- [ ] *`$` in a real path from `mdot.dirs`* (ADR 0020, ADR 0043): a `dst` built from a dir whose
  real path contains `$` is rejected as a load error. Revisit with Windows support.

== Phase 0 experiments (`research.typ`, Methodology)
- [ ] *Re-scope Phase 0* to the experiments that gate Phase 1: S4 and S6. Move S1/S2 (Phase 4),
  S3 (Phase 5) and S5 (Phase 2) to the phase they belong to.
- [ ] *Rewrite S6.* It ports per-host parts to `enabled(...)`, which ADR 0019 superseded; it should
  test `hosts/` + `depends` + `mdot.vars` instead.
- [ ] *Run S4*: loader + planner (links only) on the real `~/dotfiles-v2` translation.
- [ ] *Run S6* (rewritten).

= Implementation details (decided in code, not docs)

== State and the 3-way diff
- [ ] *Planner details* (ADR 0035).
  - How the comparisons of differently shaped live / recorded / desired values are typed. Partly:
    one comparison per pair, live vs desired optional (ADR 0057). The Rust typing is still open.
  - Its "virtual vs `std::variant`" question is now a Rust one (trait or enum).

== Rust libraries (ADR 0036)
- [ ] *clap and `--color`* (ADR 0086): whether clap's own usage errors follow `--color`.
- [ ] *Logging leftovers* (ADR 0059). How user output and debug logs are separated, the conflict
  marker, the default level, the env var name.
