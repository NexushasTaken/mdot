#import "../template.typ": adr

#adr(number: 66, title: [Dependency order is the written order, first reach], status: [Accepted], date: [2026-10-27])[
= Context
`design.typ` collects the reachable specs "in dependency order", and `plan` (ADR 0051), `apply`
(ADR 0052) and `specs` (ADR 0065) print specs in that order. The only rule written down was that a
spec comes after the specs it depends on. Specs with no dependency between them could come in any
order, so the same repo could print different orders. ADR 0065 left this open. `specs/*/` is listed
in sorted order, but only to make error messages deterministic. A spec reached more than once is
applied once (ADR 0019).

= Options
- *Between unrelated specs:* the order the names are written in `depends`, or sorted by name
  (of the specs whose deps are done, take the alphabetically first).
- *A spec reached twice:* placed where it is first reached, or where it is last reached.

= Decision
From the author:

- *Written order.* A spec comes right after its deps, and deps are taken in the order they appear
  in `depends`. The author's reason: the order in which they appear in `depends` _is_ the order, so
  there is no need to sort.
- *First reach.* A spec reached more than once is placed where it is first reached. (Last reach
  was ruled out because it can put a spec before one of its deps.)

```
visit(spec):
    if spec in done: return
    for d in spec.depends, in written order:
        visit(d)
    output(spec)
    done.add(spec)

for d in host.depends, in written order:
    visit(d)
```

Examples (`laptop` is the host; the rest are specs):

#table(
  columns: 2,
  [*`depends`*], [*Order*],
  [`laptop`: `wm`, `bash`; `wm`: `hypr`, `waybar`], [hypr, waybar, wm, bash],
  [`laptop`: `bash`, `wm`; `wm`: `hypr`, `waybar`], [bash, hypr, waybar, wm],
  [`laptop`: `wm`, `term`; `wm`: `hypr`, `fonts`; `term`: `fonts`, `foot`],
  [hypr, fonts, wm, foot, term],
)

Accepted additions proposed by Claude (accepted as a whole, without reasons of their own):

- *Scope:* this rule is "dependency order" everywhere it is used: the `SpecSet` (`design.typ`,
  Loading), `plan` (ADR 0051), `apply` (ADR 0052) and `specs` (ADR 0065).
- *Recording:* `design.typ` Loading states the rule with the `fonts` example; ADR 0065's open item
  on the order of unrelated specs is closed by this ADR.

= Consequences
- The same repo always prints and applies specs in the same order, and the user controls it by
  reordering `depends`.
- Reordering names in `depends` changes the plan's layout, not what is applied.
- The `not reached:` line of `specs` stays sorted (ADR 0065); those specs have no `depends` order.
]
