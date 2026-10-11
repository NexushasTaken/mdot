#import "../template.typ": adr

#adr(number: 17, title: [`enabled(bool)` is an eager boolean over `host.name`], status: [Superseded by 0019], date: [2026-10-10])[
= Context
ADR 0006 chose `enabled(<lua expr>)` over `host`, `os`, `vars` and `env()`. With implicit specs (ADR
0014) there is no `spec.lua` to hold it. RQ5 asked whether `enabled` should be lazy.

= Options
- Implicit specs cannot be conditional; making one conditional means adding a `spec.lua`.
- Or a per-host list in `config.lua` that can disable implicit specs too.
- Eager boolean, or a lazily evaluated function.

= Decision
`enabled(bool)` is a clause in `spec.lua`. It is a plain boolean, evaluated when the file loads;
default `true`. The only value exposed to specs is `host.name` (the hostname). A disabled spec is
treated like a deleted one, so its links appear as removals in `plan`. A conditional spec that was
implicit is restructured into `spec.lua` plus a `config/` folder, because a whole-directory link
would otherwise pull `spec.lua` into the target. Host logic stays in the spec, not in `config.lua`.

= Consequences
- Refines ADR 0006: `os`, `vars` and `env()` are dropped from Phase 1 and added when needed.
- Eager evaluation is enough while `depends` is deferred; a function form can be added later.
- Open: a `--host <name>` flag so `plan` can show what another machine would get.
- Open: what an enabled spec depending on a disabled one means, once `depends` exists.
]
