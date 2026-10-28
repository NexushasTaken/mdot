// TODO list of open items: anything still to decide or fix in the docs. Not part of the ADR
// index. Remove an item once the ADR or spec fix that closes it is written; move any follow-up
// that is still open into its own item first.

#set page(margin: 2cm)
#set text(size: 10pt)

= Phase 0 and 1: feature complete

Goal: Phase 0 and Phase 1 fully specified (plan A, 2026-10-27). Later phases stay sketches. When
designing the state record, check that a download record (ADR 0032) fits the same shape.

== Blocking Phase 1
- [ ] *Prompt mechanics* (ADR 0062, 0068): wording, how an answer is read, what counts as yes, EOF or
  Ctrl-C at the prompt.
- [ ] *`state.json` leftovers* (ADR 0060). Exact download fields, migration details.
- [ ] *Empty `mdot.opt` in Phase 1* (ADR 0061). Whether it ships.
- [ ] *State directory and lock path on macOS and Windows* (ADR 0062, 0063).
- [ ] *Replacement for `print`* (ADR 0013). Settled so far: `mdot.print`, tagged with file:line.
  `mdot.print` goes to stdout (ADR 0050). Still open: whether a spec can choose a stream
  (`mdot.stdout.print` / `mdot.stderr.print`), and where its lines appear relative to the plan
  (ADR 0051, Open). Also: `mdot.print` is missing from the `mdot` global's member list, which says
  any other member is an error.
- [ ] *Exit codes for the hostname errors* (ADR 0070): 2 (error) or 1 (broken rule), e.g. for an
  uppercase `--host`.
- [ ] *`mdot.os` under `--host`* (ADR 0013 "Host and OS info", ADR 0065). The fields other than
  `hostname` still describe the real machine.
- [ ] *`file.link` `src` validation.* An absolute `src`, or one whose `..` escapes the spec
  directory: allowed or an error?

== Inconsistencies and stale text in `design.typ`
- [ ] The 3-way diff conflict example uses `error: hypr: cannot link ...`; ADR 0050/0051 use
  `conflict: <path>: <message>`.
- [ ] The flat-clause list under *Groups* names `enabled` (superseded by ADR 0019) and `config`
  (never defined).
- [ ] ADR 0020's rule "a `$` anywhere in `dst` is a load error" is missing from `file.link()`.
- [ ] `plan --diff` is in the CLI table but never defined.
- [ ] *Purity vs the lock file:* `research.typ` says `mdot plan` never modifies the filesystem,
  but ADR 0063 has `plan` create the state directory and the lock file if they are missing.
- [ ] `-q` and `--color` have no ADR (ADR 0050 decides color from the terminal and `NO_COLOR`):
  decide, or drop them from Phase 1.

== Later phases (not blocking)
- [ ] *Removing a package* (ADR 0028, ADR 0061): what it does. Phase 5.
- [ ] *A drift-only command* (ADR 0064): whether one returns in a later phase.

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
- [ ] *Logging leftovers* (ADR 0059). How user output and debug logs are separated, the conflict
  marker, the default level, the env var name.
