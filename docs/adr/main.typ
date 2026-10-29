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
  columns: (auto, 3fr, 2fr),
  [ADR], [Title], [Status],
  link(<adr-0001>)[0001], [Fresh design instead of a comtrya port], [Accepted],
  link(<adr-0002>)[0002], [Stack: C++20, CMake, vcpkg, sol2, tl::expected, Catch2], [Superseded by 0036 (vcpkg earlier by 0025)],
  link(<adr-0003>)[0003], [Plain-Lua, lazy.nvim-style spec DSL], [Accepted],
  link(<adr-0004>)[0004], [Auto-merged `specs/` folder with mirror roots], [Superseded by 0014],
  link(<adr-0005>)[0005], [One spec owns at most one package], [Accepted (`pkg` default amended by 0014)],
  link(<adr-0006>)[0006], [Per-host variation via `enabled(<lua expr>)`], [Superseded by 0019],
  link(<adr-0007>)[0007], [System-scope files are root-owned copies, not symlinks], [Proposed],
  link(<adr-0008>)[0008], [Tree-sitter structural editing instead of templating], [Accepted (strictness rules Proposed; "instead of templating" amended by 0037)],
  link(<adr-0009>)[0009], [Resource model with a 3-way diff], [Accepted (link/git split in 0031)],
  link(<adr-0010>)[0010], [Git-based generations and rollback], [Accepted (state path changed by 0062)],
  link(<adr-0011>)[0011], [Configurable removal policy, recorded at apply time], [Superseded by 0061],
  link(<adr-0012>)[0012], [Core config manager first; packages and extras later], [Accepted],
  link(<adr-0013>)[0013], [Spec loading is pure and sandboxed], [Accepted (`print` replaced by 0078)],
  link(<adr-0014>)[0014], [One directory per spec, implicit or explicit], [Accepted (applies-everything rule superseded by 0019)],
  link(<adr-0015>)[0015], [`link(src, dst)` with plain paths, `spec.lua` is absolute], [Accepted],
  link(<adr-0016>)[0016], [Link conflicts are hard errors; parent directories are tracked], [Accepted],
  link(<adr-0017>)[0017], [`enabled(bool)` is an eager boolean over `host.name`], [Superseded by 0019],
  link(<adr-0018>)[0018], [`spec { ... }` collects declarative clauses], [Accepted],
  link(<adr-0019>)[0019], [Specs are opt-in; hosts select them through `depends`], [Accepted (`plan --host` and `apply --host` superseded by 0071)],
  link(<adr-0020>)[0020], [`dst` expands only a leading `~`], [Accepted],
  link(<adr-0021>)[0021], [Drop `name()`, reject same-`dst` conflicts, add a `package` clause], [Accepted],
  link(<adr-0022>)[0022], [`link` has a batch form: `link { names..., into = dir, dot? }`], [Accepted],
  link(<adr-0023>)[0023], [Resource clauses are grouped: `link` becomes `file.link`], [Accepted],
  link(<adr-0024>)[0024], [`net.download` fetches one pinned file], [Accepted],
  link(<adr-0025>)[0025], [Dependencies come from Conan, with libcurl and OpenSSL for downloads], [Superseded by 0036],
  link(<adr-0026>)[0026], [`file.copy` and `net.download` share one regular-file mechanism], [Accepted],
  link(<adr-0027>)[0027], [`requires` declares raw packages; `depends` names specs only], [Accepted (parts Proposed)],
  link(<adr-0028>)[0028], [Only packages mdot installed are removable; the record is mdot's own], [Proposed],
  link(<adr-0029>)[0029], [`apply` records state after each step and stops at the first failure], [Accepted ("not attempted" in the message superseded by 0052, exit code 3 by 0053)],
  link(<adr-0030>)[0030], [The 3-way diff for links], [Accepted],
  link(<adr-0031>)[0031], [mdot does not track linked content; `status` shows only mdot's resources], [Accepted (`status` removed by 0064)],
  link(<adr-0032>)[0032], [The 3-way diff for downloads], [Accepted (content key redefined by 0074)],
  link(<adr-0033>)[0033], [Link updates and deletes change the disk first, then state], [Accepted],
  link(<adr-0034>)[0034], [The planner matches desired and recorded resources by ID], [Accepted (ID parts in 0054, 0055, 0056)],
  link(<adr-0035>)[0035], [A generic planner: classify each ID, then the kind decides], [Accepted (apply order amended by 0054; `both` and `match` refined by 0057, fallback by 0058)],
  link(<adr-0036>)[0036], [The implementation language is Rust], [Accepted (its logging and JSON items closed by 0059)],
  link(<adr-0037>)[0037], [Several templating engines; Yolk-style markers first, with a git clean filter], [Accepted],
  link(<adr-0038>)[0038], [A global `mdot` table; `config.lua` defines `mdot.vars`, hosts only override], [Accepted],
  link(<adr-0039>)[0039], [`mdot.vars` is typed by a schema built from base; the "User's fault" boundary is widened], [Accepted],
  link(<adr-0040>)[0040], [The `host` global becomes `mdot.os.hostname`], [Accepted (`--host` value is now the `preview` / `specs --host` name, 0071)],
  link(<adr-0041>)[0041], [`mdot` has no built-in alias], [Accepted],
  link(<adr-0042>)[0042], [No spec-declared defaults; `config.lua` is the only place vars are defined], [Accepted],
  link(<adr-0043>)[0043], [`mdot.dirs` holds the common dirs; implicit specs keep `~/.config`], [Accepted],
  link(<adr-0044>)[0044], [`mdot.os` describes the real machine: name, family, arch and comtrya's fields], [Accepted],
  link(<adr-0045>)[0045], [`mdot.opt` holds mdot's own settings; each option says who may set it], [Accepted (deferred until its first option, 0076)],
  link(<adr-0046>)[0046], [No `mdot.g`; unknown `mdot` members are errors], [Accepted],
  link(<adr-0047>)[0047], [Command-line flags have no matching `mdot.opt` options; a flag wins], [Accepted (`--host` no longer global, 0071)],
  link(<adr-0048>)[0048], [Every file gets a fresh environment; shared library tables are read-only], [Accepted],
  link(<adr-0049>)[0049], [No `require` for now; `mdot.vars` holds only data], [Accepted],
  link(<adr-0050>)[0050], [Output streams and diagnostic markers], [Accepted (stream choice closed by 0078)],
  link(<adr-0051>)[0051], [Layout of `mdot plan` and the `--verbose` levels], [Accepted (conflict position superseded by 0052; print position closed by 0078)],
  link(<adr-0052>)[0052], [Output of `mdot apply`; step lines print when a step finishes], [Accepted (exit code 3 superseded by 0053; confirmation closed by 0068; refusal output by 0069; prompt mechanics by 0072)],
  link(<adr-0053>)[0053], [Exit codes: 0 success, 1 refused by a rule, 2 error], [Accepted],
  link(<adr-0054>)[0054], [The kind is part of the resource ID], [Accepted (its open spec and path items closed by 0055, 0056)],
  link(<adr-0055>)[0055], [The spec is not part of the resource ID; the record stores its owner], [Accepted],
  link(<adr-0056>)[0056], [IDs use the expanded, absolute, lexically normal path], [Accepted],
  link(<adr-0057>)[0057], [Classify compares each pair on its own; live vs desired is optional], [Accepted],
  link(<adr-0058>)[0058], [Every kind's `decide` handles every case; no fallback], [Accepted (its `on_remove` open item closed by 0061)],
  link(<adr-0059>)[0059], [Logging uses `tracing`; state files use `serde_json`], [Accepted],
  link(<adr-0060>)[0060], [`state.json` is a versioned flat resource list with top-level `created_dirs`], [Accepted (its `on_remove` open item closed by 0061; `repo` field and repo-id item by 0062; download fields by 0074; migration rules by 0075)],
  link(<adr-0061>)[0061], [No removal policy; removed resources follow their kind's table], [Accepted],
  link(<adr-0062>)[0062], [One state directory; the stored repo path is checked on every run], [Accepted (locking open item closed by 0063; prompt wording changed and mechanics closed by 0072; exit code after a no by 0073; path changed and macOS/Windows item closed by 0077)],
  link(<adr-0063>)[0063], [An OS file lock on the state directory: shared for readers, exclusive for `apply`], [Accepted (`status` removed by 0064; path changed by 0077)],
  link(<adr-0064>)[0064], [No `mdot status` command; `plan` reports drift], [Accepted (`--host` scope superseded by 0071)],
  link(<adr-0065>)[0065], [`mdot specs` output and `<spec-name>`], [Accepted (spec order closed by 0066; exit codes by 0067; `mdot.os` under `--host` by 0071)],
  link(<adr-0066>)[0066], [Dependency order is the written order, first reach], [Accepted],
  link(<adr-0067>)[0067], [Every missing spec or host name exits with 2], [Accepted (`--host` case moved to `preview` and `specs --host` by 0071)],
  link(<adr-0068>)[0068], [`apply` asks once as a guard against running it by accident; `--yes` skips it], [Accepted (refusal output closed by 0069; prompt mechanics by 0072)],
  link(<adr-0069>)[0069], [`apply` refuses on conflicts with one line that points to `mdot plan`], [Accepted],
  link(<adr-0070>)[0070], [The hostname comes from the OS's stable name, lowercased; bad names warn, unsafe ones are errors], [Accepted (`--host` rules extended to `preview` and missing-hostname message changed by 0071)],
  link(<adr-0071>)[0071], [`mdot preview <host>` replaces `plan --host`: `plan`'s format against an empty machine], [Accepted],
  link(<adr-0072>)[0072], [Prompts read one line like pacman: `y`/`yes` is yes, anything else is no], [Accepted (repo-prompt exit code closed by 0073)],
  link(<adr-0073>)[0073], [A no at the repo-path prompt exits with 1], [Accepted],
  link(<adr-0074>)[0074], [A download record stores its normalized `url`; a changed `url` downloads again], [Accepted],
  link(<adr-0075>)[0075], [Every `state.json` format change bumps `version`; an unknown field is an error], [Accepted],
  link(<adr-0076>)[0076], [`mdot.opt` does not exist in Phase 1; ADR 0045 waits for its first option], [Accepted],
  link(<adr-0077>)[0077], [The state directory is `<base>/mdot-data` on every OS; `XDG_STATE_HOME` is read everywhere], [Accepted],
  link(<adr-0078>)[0078], [`mdot.print` replaces `print`; lines are written when called], [Accepted],
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
#include "0037-marker-templating.typ"
#include "0038-mdot-global-and-vars.typ"
#include "0039-typed-vars.typ"
#include "0040-mdot-os-hostname.typ"
#include "0041-no-mdot-alias.typ"
#include "0042-no-spec-declared-defaults.typ"
#include "0043-mdot-dirs.typ"
#include "0044-mdot-os-fields.typ"
#include "0045-mdot-opt.typ"
#include "0046-no-mdot-g.typ"
#include "0047-flags-are-cli-only.typ"
#include "0048-file-isolation.typ"
#include "0049-no-require-for-now.typ"
#include "0050-output-streams-and-markers.typ"
#include "0051-plan-layout.typ"
#include "0052-apply-output.typ"
#include "0053-exit-codes.typ"
#include "0054-kind-is-part-of-the-id.typ"
#include "0055-spec-is-not-part-of-the-id.typ"
#include "0056-ids-use-the-expanded-lexical-path.typ"
#include "0057-three-comparisons-optional-live-desired.typ"
#include "0058-every-kind-decides-every-case.typ"
#include "0059-logging-and-state-file-libraries.typ"
#include "0060-state-file-schema.typ"
#include "0061-no-removal-policy.typ"
#include "0062-single-state-dir-and-repo-check.typ"
#include "0063-state-lock.typ"
#include "0064-no-status-command.typ"
#include "0065-specs-output.typ"
#include "0066-dependency-order.typ"
#include "0067-missing-name-exit-code.typ"
#include "0068-apply-confirmation.typ"
#include "0069-apply-refusal-message.typ"
#include "0070-hostname-source.typ"
#include "0071-preview-command.typ"
#include "0072-prompt-mechanics.typ"
#include "0073-repo-prompt-no-exit-code.typ"
#include "0074-download-record-fields.typ"
#include "0075-state-version-bumps.typ"
#include "0076-no-mdot-opt-in-phase-1.typ"
#include "0077-state-dir-per-os.typ"
#include "0078-mdot-print.typ"
