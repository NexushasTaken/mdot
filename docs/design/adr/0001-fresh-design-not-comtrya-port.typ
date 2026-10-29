#import "../template.typ": adr

#adr(number: 1, title: [Fresh design instead of a comtrya port], status: [Accepted], date: [2026-10-06])[
= Context
The first plan (`archive/comtrya-port-plan.md`) was a 1:1 C++ port of comtrya. The author's pain
points (no config↔package unit, no removal/drift tracking, hacky AUR handling, weak plan output) are
properties of comtrya's model, not of its implementation language. The author's fork already had to
patch core behaviour (hooks, failure handling, output ordering).

= Options
+ Keep porting, steer toward missing features.
+ Fresh design, new stack.
+ Fresh design, keep the stack already decided in the port plan.

= Decision
Option 3. Design mdot around the author's dotfile workflow; reuse the port plan's stack decisions and
ideas only where they fit.

= Consequences
- The port plan is archived, not deleted.
- None of comtrya's provisioning breadth (users, groups, 13 package providers, macOS defaults) is
  inherited by default; each must be justified anew.
- Existing comtrya manifests must be rewritten (see `research.typ`, Appendix A).
]
