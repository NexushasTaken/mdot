#import "../template.typ": *

#show: base.with(title: "mdot — Architecture Decision Records")

#titleblock([mdot — Architecture Decision Records], meta: [2026-10-06])

One record per decision: Context / Options / Decision / Consequences. ADRs are snapshots: never edit
an accepted ADR's decision; supersede it with a new one. Each record lives in its own file in this
directory and is collected here.

*Status meanings*

- *Accepted* — decided by the author (in the design interview or the earlier design session).
- *Proposed* — introduced while writing the design and approved only as part of the overall plan,
  not discussed on its own. Confirm or supersede before the relevant phase starts.

#table(
  columns: (auto, 1fr, auto),
  [ADR], [Title], [Status],
  link(<adr-0001>)[0001], [Fresh design instead of a comtrya port], [Accepted],
  link(<adr-0002>)[0002], [Stack: C++20, CMake, vcpkg, sol2, tl::expected, Catch2], [Accepted],
  link(<adr-0003>)[0003], [Plain-Lua, lazy.nvim-style spec DSL], [Accepted],
  link(<adr-0004>)[0004], [Auto-merged `specs/` folder with mirror roots], [Superseded by 0014],
  link(<adr-0005>)[0005], [One spec owns at most one package], [Accepted (`pkg` default amended by 0014)],
  link(<adr-0006>)[0006], [Per-host variation via `enabled(<lua expr>)`], [Accepted],
  link(<adr-0007>)[0007], [System-scope files are root-owned copies, not symlinks], [Proposed],
  link(<adr-0008>)[0008], [Tree-sitter structural editing instead of templating],
  [Accepted (strictness rules Proposed)],
  link(<adr-0009>)[0009], [Resource model with a 3-way diff], [Proposed],
  link(<adr-0010>)[0010], [Git-based generations and rollback], [Accepted],
  link(<adr-0011>)[0011], [Configurable removal policy, recorded at apply time],
  [Accepted (recording Proposed)],
  link(<adr-0012>)[0012], [Core config manager first; packages and extras later], [Accepted],
  link(<adr-0013>)[0013], [Spec loading is pure and sandboxed], [Proposed],
  link(<adr-0014>)[0014], [One directory per spec, implicit or explicit], [Accepted],
)

#include "0001-fresh-design-not-comtrya-port.typ"
#include "0002-stack.typ"
#include "0003-plain-lua-spec-dsl.typ"
#include "0004-auto-merge-specs-folder.typ"
#include "0005-one-spec-owns-one-package.typ"
#include "0006-per-host-via-enabled.typ"
#include "0007-system-scope-copies.typ"
#include "0008-tree-sitter-structural-editing.typ"
#include "0009-three-way-diff-resource-model.typ"
#include "0010-git-based-generations.typ"
#include "0011-removal-policy-recorded-at-apply.typ"
#include "0012-core-first-roadmap.typ"
#include "0013-pure-sandboxed-spec-loading.typ"
#include "0014-per-spec-directories.typ"
