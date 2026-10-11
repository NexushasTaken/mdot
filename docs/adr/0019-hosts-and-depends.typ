#import "../template.typ": adr

#adr(number: 19, title: [Specs are opt-in; hosts select them through `depends`], status: [Accepted], date: [2026-10-11])[
= Context
ADR 0014 applied every directory in `specs/`, and ADR 0017 handled per-machine variation with
`enabled()` inside each spec. The author wants to know _why_ a config and its package are present
(Hyprland needs a portal, a bar, a notification daemon), and likes the NixOS idea of a machine
that selects modules. In NixOS a module does nothing until a switch is turned on, either by the
host or by another module.

= Options
- Keep applying everything; `depends` only orders and validates.
- Specs are opt-in: nothing applies unless a host reaches it through `depends`.
- Specs found through an `import "specs/"` call, resolved relative to the caller.

= Decision
`specs/` is a library. Nothing in it is applied unless a host reaches it.
- *Hosts.* `hosts/<hostname>.lua` is the root of a machine: `return spec { depends(...) }`. mdot
  applies every spec reachable from it. A host file has no directory, so only selection clauses
  (`depends`, later `config`) are valid in it; `link` is an error.
- *Groups.* A spec may contain only `depends`, to name a bundle such as `desktop`.
- *Resolution.* `depends(names...)` always looks names up in `<repo root>/specs/`, never relative
  to the calling file. There is no `import`. Unknown names, listing the names found, and cycles,
  naming the cycle, are errors. A spec reached twice is applied once.
- *Implicit specs* have no `spec.lua`, so they cannot depend on anything; they are leaves.
- *Removal.* A spec that is no longer reachable counts as removed, so `plan` shows its links as
  removals (the same treatment the disabled case had in ADR 0017).
- *`--host <name>`.* `plan` and `status` accept it and load `hosts/<name>.lua` as a dry run.
  `apply` with a `--host` that differs from the real hostname is an error, because it would write
  another machine's links and state here. `plan` should print `host: <name> (simulated)`. Conflicts it
  reports still describe this machine's disk.
- `enabled()` is removed.

= Consequences
- Supersedes ADR 0017 and ADR 0006. Supersedes the "every spec applies" part of ADR 0014; the
  layout and the implicit and explicit modes stand.
- Per-machine variation now lives in the host file, not in each spec, and `host.name` is no longer
  used by any Phase 1 clause.
- With packages (Phase 5) a spec's own package can be installed as explicit and a dependency's as a
  dependency, so a command can answer "why is this here?" (not designed).
- Open: whether `name()` stays. `depends` uses the directory name today.
- Open: two specs linking the same `dst`. Likely an error naming both specs, as in ADR 0016.
- Parked: `config { git = { user, email } }` for per-spec settings. A symlink cannot carry values,
  so it needs a generating clause (`render`, Phase 4, or a small generated file such as a git
  `[include]`). Preferred shape is a plain table keyed by spec name, not a global function per spec;
  defaults declared by the spec, overridden by the host.
- Open: sharing the repo with other people. A new `hosts/<name>.lua` is an untracked file, so it does
  not conflict with updates but still shows in `git status`. Options are to commit it on a fork, to
  list it in `.git/info/exclude`, or later to keep personal files outside the repo (an overlay).
]
