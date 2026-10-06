#import "../template.typ": adr

#adr(number: 11, title: [Configurable removal policy, recorded at apply time], status: [Accepted (recording at apply time: Proposed)], date: [2026-10-06])[
= Context
When a spec is removed, should mdot uninstall the package and remove files, ask first, or only
unlink? The author wanted all options, configurable per spec, with a default.

= Decision
`on_remove { files = "remove"|"ask"|"keep", package = "uninstall"|"ask"|"keep" }` per spec;
`config.lua` `defaults.on_remove` overrides the built-in default (`files = "remove"`,
`package = "ask"`; patched files are never touched).

Proposed: the effective policy is *stored in state at apply time*, because the spec file is usually
gone by the time its resources are deleted.

= Consequences
- Changing a spec's policy only takes effect after the next apply.
- Deleting a rendered copy whose live content differs from recorded is a conflict, not a delete.
]
