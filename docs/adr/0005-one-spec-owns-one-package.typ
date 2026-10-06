#import "../template.typ": adr

#adr(number: 5, title: [One spec owns at most one package], status: [Accepted], date: [2026-10-06])[
= Context
The core unit should be "this config belongs to this package". The interview considered how strictly
mdot should own packages (all explicit packages, only its own, or its own plus warnings).

= Decision
The author's rule: a spec's config is the config *for one specific package*. A spec owns at most one
package (`name()` with `pkg = true`); other packages are only _referenced_ through `depends`.
Package-only specs (`spec { name("hyprshot") }`) and config-only specs (`pkg = false`) are allowed.
When providers exist, owned packages install as explicit and depends-only packages as dependencies.

= Consequences
- Multi-package programs split into one owning spec plus package-only specs.
- mdot does not claim ownership of the whole system's explicit package list.
- Coexistence with pacman's install reasons is research question RQ2.
]
