#import "../template.typ": adr

#adr(number: 21, title: [Drop `name()`, reject same-`dst` conflicts, add a `package` clause], status: [Accepted], date: [2026-10-11])[
= Context
ADR 0019 left three items open: whether `name()` stays, what happens when two specs link the same
`dst`, and how a spec says it needs a package. The earlier idea of a spec "owning" a package through
`name()` with `pkg = true` no longer fits, because the directory name is already the identity.

= Decision
- *`name()` is removed.* The directory name is the identity that `depends` resolves. Two sources of
  identity could disagree.
- *Same `dst` in two reachable specs is an error.* The error names both specs and the `dst`. The
  same applies inside one spec. There is no precedence and no override. Because the reachable set is
  known after `depends` is resolved, the check runs at plan time, before anything is written.
- *`apply` never runs past plan errors.* `apply` builds the same plan as `plan`. If the plan has any
  error (load errors, unknown names, cycles, missing `src`, `dst` conflicts, unmanaged files at a
  `dst`), `apply` stops before the first write. Plan reports every error it can find in one run, not
  just the first.
- *`package` is a clause.* A spec states that it needs a package. It does not "own" one by
  existing.
  - `package()` with no arguments uses the spec's directory name as the package name.
  - `package(name, opts)` gives an explicit name. `opts` carries the per-platform alternatives
    (`pkg_alts`); its exact fields are decided in Phase 5.
  - A spec with only `package()` is valid, since the spec is not empty. This is how a package-only
    spec (a theme, a driver) is written.
  - Implicit specs have no `spec.lua`, so they cannot call `package`. To give `nvim/` a package, add
    a `spec.lua` with `link(...)` and `package("neovim")`.

= Consequences
- Updates ADR 0019: its open items on `name()` and same-`dst` are closed.
- Replaces the "owned package (`name()` with `pkg = true`)" wording in the package semantics of the
  design.
- Phase 5, not Phase 1: `package` is not implemented yet, but the loader must accept the clause
  shape so it need not change later.
- Open: install reason. Whether a package is explicit when a host names the spec directly and a
  dependency when another spec pulls it in through `depends`.
]
