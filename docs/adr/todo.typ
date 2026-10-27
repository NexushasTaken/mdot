// TODO list of open items: anything still to decide or fix in the docs. Not part of the ADR
// index. Tick an item when the ADR or spec fix that closes it is written.

#set page(margin: 2cm)
#set text(size: 10pt)

= Phase 0 and 1: feature complete

Goal: Phase 0 and Phase 1 fully specified (plan A, 2026-10-27). Later phases stay sketches. When
designing the state record, check that a download record (ADR 0032) fits the same shape.

== Blocking Phase 1
- [x] *`state.json` schema* (ADR 0060). Versioned flat `resources` list, link record = `kind`,
  `spec`, `src`, `dst`; top-level `created_dirs` with derived usage. Still open there: exact download
  fields, migration details (`on_remove` closed by ADR 0061).
- [x] *How `on_remove` reaches `decide`* (ADR 0061). Dropped: no removal policy; removed resources
  follow their kind's table. Supersedes ADR 0011. Still open there: what removing a package does
  (ADR 0028), and whether an empty `mdot.opt` ships in Phase 1.
- [x] *Repo-id* (ADR 0062). No repo-id: one state directory `$XDG_STATE_HOME/mdot/`; `state.json`
  stores the repo path and a different path warns and asks (refuses without a terminal). Still open
  there: the state directory on macOS and Windows, prompt mechanics shared with ADR 0052.
- [x] *Locking* (ADR 0063). OS file lock on `$XDG_STATE_HOME/mdot/lock`: shared for `plan` /
  `status`, exclusive for `apply`; a run that can't lock errors with exit 1. Still open there: the
  lock path on macOS and Windows (with ADR 0062's state directory).
- [ ] *`mdot status` output.* Not designed; Phase 1 acceptance test step 5 depends on it.
- [ ] *`mdot specs` output.* Not designed (minor).
- [ ] *`apply` confirmation* (ADR 0052, Open). The prompt, `--yes` (already in the CLI table), and
  what `apply` prints when it refuses because of conflicts.
- [ ] *Replacement for `print`* (ADR 0013). Settled so far: `mdot.print`, tagged with file:line.
  `mdot.print` goes to stdout (ADR 0050). Still open: whether a spec can choose a stream
  (`mdot.stdout.print` / `mdot.stderr.print`), and where its lines appear relative to the plan
  (ADR 0051, Open). Also: `mdot.print` is missing from the `mdot` global's member list, which says
  any other member is an error.
- [ ] *Hostname source* (ADR 0040). Where the real hostname comes from (`gethostname()`,
  `/etc/hostname`, per OS). Matters for cross-platform.
- [ ] *`file.link` `src` validation.* An absolute `src`, or one whose `..` escapes the spec
  directory: allowed or an error?

== Inconsistencies and stale text in `design.typ`
- [ ] The 3-way diff conflict example uses `error: hypr: cannot link ...`; ADR 0050/0051 use
  `conflict: <path>: <message>`.
- [ ] The flat-clause list under *Groups* names `enabled` (superseded by ADR 0019) and `config`
  (never defined).
- [ ] ADR 0020's rule "a `$` anywhere in `dst` is a load error" is missing from `file.link()`.
- [ ] `plan --diff` is in the CLI table but never defined.
- [ ] `-q` and `--color` have no ADR (ADR 0050 decides color from the terminal and `NO_COLOR`):
  decide, or drop them from Phase 1.

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
- [x] *Logging:* `tracing` + `tracing-subscriber` for user output and debug logs (ADR 0059). Open: how the two outputs are separated, conflict marker, default level, env var name.
- [x] *State files:* `serde` + `serde_json` (ADR 0059).
