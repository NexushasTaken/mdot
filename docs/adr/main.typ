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
  link(<adr-0002>)[0002], [Stack: C++20, CMake, vcpkg, sol2, tl::expected, Catch2],
  [Superseded by 0036 (vcpkg earlier by 0025)],
  link(<adr-0003>)[0003], [Plain-Lua, lazy.nvim-style spec DSL], [Accepted],
  link(<adr-0004>)[0004], [Auto-merged `specs/` folder with mirror roots], [Superseded by 0014],
  link(<adr-0005>)[0005], [One spec owns at most one package], [Accepted (`pkg` default amended by 0014)],
  link(<adr-0006>)[0006], [Per-host variation via `enabled(<lua expr>)`], [Superseded by 0019],
  link(<adr-0007>)[0007], [System-scope files are root-owned copies, not symlinks], [Proposed],
  link(<adr-0008>)[0008], [Tree-sitter structural editing instead of templating],
  [Accepted (strictness rules Proposed)],
  link(<adr-0009>)[0009], [Resource model with a 3-way diff], [Accepted (link/git split in 0031)],
  link(<adr-0010>)[0010], [Git-based generations and rollback], [Accepted],
  link(<adr-0011>)[0011], [Configurable removal policy, recorded at apply time],
  [Accepted (recording Proposed)],
  link(<adr-0012>)[0012], [Core config manager first; packages and extras later], [Accepted],
  link(<adr-0013>)[0013], [Spec loading is pure and sandboxed], [Accepted],
  link(<adr-0014>)[0014], [One directory per spec, implicit or explicit], [Accepted (applies-everything rule superseded by 0019)],
  link(<adr-0015>)[0015], [`link(src, dst)` with plain paths, `spec.lua` is absolute], [Accepted],
  link(<adr-0016>)[0016], [Link conflicts are hard errors; parent directories are tracked], [Accepted],
  link(<adr-0017>)[0017], [`enabled(bool)` is an eager boolean over `host.name`], [Superseded by 0019],
  link(<adr-0018>)[0018], [`spec { ... }` collects declarative clauses], [Accepted],
  link(<adr-0019>)[0019], [Specs are opt-in; hosts select them through `depends`], [Accepted],
  link(<adr-0020>)[0020], [`dst` expands only a leading `~`], [Accepted],
  link(<adr-0021>)[0021], [Drop `name()`, reject same-`dst` conflicts, add a `package` clause], [Accepted],
  link(<adr-0022>)[0022], [`link` has a batch form: `link { names..., into = dir, dot? }`], [Accepted],
  link(<adr-0023>)[0023], [Resource clauses are grouped: `link` becomes `file.link`], [Accepted],
  link(<adr-0024>)[0024], [`net.download` fetches one pinned file], [Accepted],
  link(<adr-0025>)[0025], [Dependencies come from Conan, with libcurl and OpenSSL for downloads], [Superseded by 0036],
  link(<adr-0026>)[0026], [`file.copy` and `net.download` share one regular-file mechanism], [Accepted],
  link(<adr-0027>)[0027], [`requires` declares raw packages; `depends` names specs only], [Accepted (parts Proposed)],
  link(<adr-0028>)[0028], [Only packages mdot installed are removable; the record is mdot's own], [Proposed],
  link(<adr-0029>)[0029], [`apply` records state after each step and stops at the first failure], [Accepted],
  link(<adr-0030>)[0030], [The 3-way diff for links], [Accepted],
  link(<adr-0031>)[0031], [mdot does not track linked content; `status` shows only mdot's resources], [Accepted],
  link(<adr-0032>)[0032], [The 3-way diff for downloads], [Accepted],
  link(<adr-0033>)[0033], [Link updates and deletes change the disk first, then state], [Accepted],
  link(<adr-0034>)[0034], [The planner matches desired and recorded resources by ID], [Proposed],
  link(<adr-0035>)[0035], [A generic planner: classify each ID, then the kind decides], [Accepted],
  link(<adr-0036>)[0036], [The implementation language is Rust], [Accepted],
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
#include "0015-link-clause.typ"
#include "0016-link-conflicts.typ"
#include "0017-enabled-clause.typ"
#include "0018-spec-returns-clause-table.typ"
#include "0019-hosts-and-depends.typ"
#include "0020-dst-expansion.typ"
#include "0021-name-dst-conflicts-package.typ"
#include "0022-link-batch-form.typ"
#include "0023-clause-groups.typ"
#include "0024-net-download.typ"
#include "0025-conan-dependencies.typ"
#include "0026-shared-regular-file-mechanism.typ"
#include "0027-requires-clause.typ"
#include "0028-package-ownership-record.typ"
#include "0029-apply-records-each-step.typ"
#include "0030-three-way-diff-for-links.typ"
#include "0031-links-do-not-track-content.typ"
#include "0032-three-way-diff-for-downloads.typ"
#include "0033-link-update-delete-write-order.typ"
#include "0034-resource-ids-and-join.typ"
#include "0035-generic-planner.typ"
#include "0036-rust.typ"
