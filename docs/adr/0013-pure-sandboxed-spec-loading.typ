#import "../template.typ": adr

#adr(number: 13, title: [Spec loading is pure and sandboxed], status: [Accepted], date: [2026-10-23 (proposed 2026-10-06)])[
= Context
Specs are full Lua (ADR-0003). The author wants `plan` to show what will happen before anything does.
Clauses are declarations (ADR 0018), so loading a spec never needs to touch the system. This ADR
decides what spec code can reach while it loads.

The specs are the author's own. The sandbox exists for *purity*: it stops accidental side effects
during `plan`. It is not a security boundary against hostile specs.

= Options
- *Allowlist vs denylist.* Start from nothing and add what is safe, or open everything and remove
  what is dangerous.
- *Live-state helpers `env()` and `exists()`.* Keep them; drop them; keep them and have `apply`
  re-check that its clauses match what `plan` showed; defer them until a real spec needs them.

= Decision
- *Allowlist.* The author does not know every unsafe corner of Lua, so anything not listed stays
  unreachable.
- *What a spec can reach:* the libraries `string`, `table`, `math` and `utf8`, and from the base
  library `pairs`, `ipairs`, `next`, `select`, `type`, `tostring`, `tonumber`, `error`, `assert`,
  `pcall`, `setmetatable`, `getmetatable` and `print`.
- *`print` is allowed for now.* mdot will later provide its own output function to replace it.
- *Not reachable,* among everything else: `io`, `os`, `debug`, `coroutine`, `package`/`require`,
  `load`, `dofile`, `loadfile` and `string.dump`.
- *No live-state helpers.* `env()` and `exists()` are dropped. They read state that can change
  between `plan` and `apply` (a file created in between, a different shell or `sudo`), so `plan`
  would stop being a promise about `apply`. The author's real dotfiles use neither.

= Consequences
- `mdot plan` cannot have side effects caused by spec code, apart from `print` output.
- Loading a spec gives the same clauses on every run, given the same repo and host, unless the
  spec uses `math.random`.
- RQ5 is answered: per-host logic goes through `hosts/` (ADR 0019) and what mdot hands the spec,
  not through live-state helpers.

= Open
- *Isolation between files.* Whether each file gets a fresh environment, and how to stop one spec
  from changing a shared table such as `string` that every other spec sees. (The 2026-10-06
  proposal said "a fresh `sol::environment` per file"; that is not confirmed.)
- *`require`.* Whether specs can share helper modules, and from where. (The proposal said
  "restricted to the repo"; not confirmed.)
- *mdot's replacement for `print`.*
- *Apply flow.* The author wants `apply` to plan first and apply nothing if the plan has errors.
  Whether a conflict blocks everything or one link, and what happens when execution fails midway,
  is not decided.
- *Host and OS info.* Exactly what mdot passes to a spec.
]
