#import "../template.typ": adr

#adr(number: 55, title: [The spec is not part of the resource ID; the record stores its owner], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0034 left open whether the spec is part of a resource's ID: if `specs/nvim/` is renamed to
`specs/neovim/` and still links `~/.config/nvim`, is that a delete plus a create, or the same
resource?

Constraints:
- ADR 0054: the ID is `<kind>:<output>`; conflicts and freed places use the slot `<world>:<output>`.
- ADR 0021: a spec's identity is its directory name; the same `dst` in two reachable specs is an
  error, so a slot has at most one owning spec at a time.
- ADR 0033: its update example is this case (`specs/hypr/` renamed to `specs/hyprland/`, same `dst`)
  and calls it an *update*.
- ADR 0011: the `on_remove` policy is per spec and is needed after the spec is gone.
- ADR 0030 / 0031: a link's value is its `src`, which changes with the spec directory.

= Options
+ *The spec is not in the ID; the record stores the owning spec as a plain field.* Chosen.
+ *The spec is in the ID* (`link:nvim:~/.config/nvim`). A rename becomes a delete plus a create on
  the same slot (ADR 0054, rule 2). It contradicts ADR 0033's example, and under
  `on_remove.files = "keep"` the old link is forgotten instead of deleted, so the slot stays taken and
  the renamed spec's link is a conflict.
+ *The spec is not in the ID, and state does not record it.* The leanest state; ADR 0011 would need
  the policy value stored on each record, and `plan` could not say which spec a removed resource came
  from.

= Decision
From the author:
- *The spec is not part of the ID.* After renaming `nvim/` to `neovim/` the ID stays
  `link:~/.config/nvim`. Only `src` changed, not `dst`, so it is the same resource and the action is
  an *update*. ADR 0033's example holds as written.
- *The record stores the owning spec* as a plain field.

Accepted additions:
- *The owner is not compared.* `match` never looks at it, and classify and decide never read it. An
  *update* rewrites it to the new spec. Otherwise a rename alone could count as "differ".

= Consequences
- Closes ADR 0034's second open item.
- A spec rename plans as one *update* per resource, not a delete and a create.
- State has one more string per record.

= Open
- *How the removal policy is stored:* as a value on each record, or looked up by owner in a per-spec
  table in state. Belongs to ADR 0011 (its "recorded at apply" part is still Proposed).
- *What `plan` shows when the owner changes* (for example "moved from `nvim` to `neovim`"). Belongs
  to ADR 0051.
]
