# Architecture Decision Records

One file per decision. Context / Options / Decision / Consequences. ADRs are snapshots: never edit an
accepted ADR's decision; supersede it with a new one.

**Status meanings**
- **Accepted** — decided by the author (in the design interview or the earlier design session).
- **Proposed** — introduced while writing the design and approved only as part of the overall plan,
  not discussed on its own. Confirm or supersede before the relevant phase starts.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-fresh-design-not-comtrya-port.md) | Fresh design instead of a comtrya port | Accepted |
| [0002](0002-stack.md) | Stack: C++20, CMake, vcpkg, sol2, tl::expected, Catch2 | Accepted |
| [0003](0003-plain-lua-spec-dsl.md) | Plain-Lua, lazy.nvim-style spec DSL | Accepted |
| [0004](0004-auto-merge-specs-folder.md) | Auto-merged `specs/` folder with mirror roots | Accepted |
| [0005](0005-one-spec-owns-one-package.md) | One spec owns at most one package | Accepted |
| [0006](0006-per-host-via-enabled.md) | Per-host variation via `enabled(<lua expr>)` | Accepted |
| [0007](0007-system-scope-copies.md) | System-scope files are root-owned copies, not symlinks | Proposed |
| [0008](0008-tree-sitter-structural-editing.md) | Tree-sitter structural editing instead of templating | Accepted (strictness rules Proposed) |
| [0009](0009-three-way-diff-resource-model.md) | Resource model with a 3-way diff | Proposed |
| [0010](0010-git-based-generations.md) | Git-based generations and rollback | Accepted |
| [0011](0011-removal-policy-recorded-at-apply.md) | Configurable removal policy, recorded at apply time | Accepted (recording Proposed) |
| [0012](0012-core-first-roadmap.md) | Core config manager first; packages and extras later | Accepted |
| [0013](0013-pure-sandboxed-spec-loading.md) | Spec loading is pure and sandboxed | Proposed |
