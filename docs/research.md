# mdot: A Declarative, Package-Scoped Dotfile Manager

*Research document. Status: working draft, 2026-10-06.*

This is the research companion to [design.md](design.md), which holds the current spec, and
[adr/](adr/), which records individual decisions. It explains why mdot exists, what it claims, which
claims are still unproven, and how they will be tested. Everything here comes from the design
interview and from inspecting the author's existing setup (`~/dotfiles-v2`, the comtrya fork at
`~/dev/repos/comtrya`) and an earlier design session log. No outside survey has been done yet.
§9 lists that as future work.

---

## Abstract

Existing dotfile managers sit at two extremes. Some only place files: GNU stow, and the author's
previous mdot design. Others are general machine provisioners, like comtrya, that have no idea that
a config file belongs to a package. Neither tracks what it deployed, so neither can reliably remove
things or detect drift. mdot proposes a middle path:

- A **plain-Lua, package-scoped spec format** where each spec owns at most one package and that
  package's configuration.
- A **resource model with a 3-way diff** (desired × recorded × live) that makes plan, drift
  detection and removal first-class.
- **Git-based generations** for rollback.
- **Tree-sitter-based structural editing** to change config files without a text templating
  language.

The scope is ambitious. This document narrows it into testable research questions and small
experiments to run before the architecture is committed to.

---

## 1. Introduction and motivation

### 1.1 The author's setup today

The author's dotfiles (`~/dotfiles-v2`) are managed with a personally modified fork of comtrya.
Before that they used GNU stow. A typical comtrya manifest entry looks like this:

```yaml
- action: file.link
  from: waybar/
  to: "{{ user.config_dir }}/waybar"
  before:
    - action: package.install
      name: waybar
      provider: pacman
```

This pattern repeats for nearly every program, in `hyprland.yaml`, `utils.yaml`, `dev-utils.yaml`
and the `modules/*` files.

### 1.2 Observed problems

The interview identified four problems:

1. **The unit is wrong.** The real relationship is "this config belongs to this package", but the
   tool models it as two unrelated actions glued together with `before:`. Every config pays that
   verbosity cost.
2. **No removal or drift tracking.** Deleting a manifest entry leaves its link and package behind,
   and nothing reports that the system has drifted from the repo.
3. **Packages that aren't in the official repos are hacky.** AUR installs go through a Lua plugin
   (`plugins/aur.lua`) that shells out to `makepkg`. Bootstrapping `paru` is itself a plugin
   invocation (`paru.yaml`).
4. **Weak plan, error and dry-run output.** It's hard to know beforehand what will happen, or
   afterwards what did happen.

### 1.3 Evidence from the comtrya fork

The fork's commits (`ec46d076..a5b400f8`) show what the author already had to add:

- `before` / `after` hooks on actions (`f42ed59`, fixed in `3fc1973`)
- continuing after a failed action (`6ecdc02`)
- an `interactive` key for `command.run` (`03a8e72`)
- switching the Arch provider to `pacman` (`838cae0`)
- printing an action's summary before it runs (`dc9d3c5`)
- more directories in the user context (`a5b400f8`)

The tool needed patching for ordering, failure handling and output, which are core behaviours. That
is the strongest sign that extending comtrya further won't fix the underlying model.

### 1.4 Abandoned direction

The repository's first plan ([archive/comtrya-port-plan.md](archive/comtrya-port-plan.md)) was a
1:1 C++ port of comtrya. Porting would keep comtrya's model, which is the source of problems 1 and
2, so the port was dropped in favour of a fresh design. Its technology choices were kept
([ADR-0001](adr/0001-fresh-design-not-comtrya-port.md),
[ADR-0002](adr/0002-stack.md)).

---

## 2. Problem statement and scope

**Problem.** Give one user a way to declare, in a version-controlled repo, which programs they use
and how each is configured. Then reconcile a machine to that declaration, including removing what
is no longer declared, and do it with predictable, previewable and reversible steps.

**In scope.** The core research target, per the interview:

- user-level and system-level configuration files
- per-machine variation
- plan / apply / status / adopt
- removal policies
- rollback
- structural editing of config files

**Designed for, implemented later:**

- package management (pacman first)
- AUR sources
- hooks
- lockfile

**Out of scope for now:**

- user and group account management
- multi-user / system-wide user configuration
- secrets
- non-Arch backends

The interfaces are meant to be generic, with Arch as the first implementation; porting to other OSes
is deferred research.

**Non-goals,** from the stated philosophy:

- mdot will not ship knowledge of any program's config location or package names.
- It will not guess when something is ambiguous.
- It will not perform destructive actions silently.

---

## 3. Related work

This comparison is limited to tools the author has used or analysed in the earlier design session.

| Tool | Config | Deploy | Templating | Packages | Lockfile | Relevance to mdot |
|---|---|---|---|---|---|---|
| GNU Stow | directory structure | symlink | no | no | no | Its symlink model is kept, but it has no idea of packages, which is why the author left it. |
| comtrya | YAML manifests | copy / link / run actions | Tera strings | yes, multiple OSes | no | General provisioner. It has a package concept, but packages and configs are unrelated actions with no state (§1). The project was reportedly rewritten mid-2026, a warning against depending on niche tools. |
| Yolk | Rhai | symlink + inline edits | inline comment markers | no | no | Its config files stay valid whether or not the tool has processed them. That idea influenced `render`/`patch`. |
| Nix + home-manager | Nix expressions | symlinks into an immutable store | declarative options | yes | yes (`flake.lock`) | The model mdot wants (declarative, generations, rollback), but with heavy infrastructure. mdot aims for the semantics without the store. |
| lazy.nvim | Lua tables | git clone | no | plugin-scoped | yes (`lazy-lock.json`) | The source of the spec style: spec files in a folder that are merged automatically, plus a lockfile. |
| mdot.old (author's prior design) | Lua tables (`init.lua`) | stow-like symlinks | no | no | no | It had `depends`, `enabled`, `platforms` and `excludes`. Unresolved problems: how `depends` and `enabled` interact, empty System/Project scopes, and the awkward `excludes = "*"` double negative. |

**The gap.** No tool in this table combines:

- package-scoped ownership (config ↔ package)
- recorded deployment state, which enables removal and drift detection
- low infrastructure (just a binary and a git repo)

mdot targets that combination.

---

## 4. Design overview

[design.md](design.md) is the authoritative spec; the decisions are in [adr/](adr/). In summary:

- **Specs are plain Lua,** lazy.nvim-style, with no syntax extensions. Each spec owns at most one
  package. Other packages are only referenced via `depends`.
  ([ADR-0003](adr/0003-plain-lua-spec-dsl.md), [ADR-0005](adr/0005-one-spec-owns-one-package.md))
- **Spec files are auto-merged** from `specs/**/*.lua`. Mirror directories (`configs/`, `home/`,
  `system/etc/`, …) hold the files. ([ADR-0004](adr/0004-auto-merge-specs-folder.md))
- **Per-machine variation** uses ordinary Lua expressions in `enabled(...)`.
  ([ADR-0006](adr/0006-per-host-via-enabled.md))
- **Four deployment kinds:** `config` (symlink), `render` (base file + edits → copy), `patch`
  (enforce parts of an app-owned file), and `sysfile` (root-owned copy).
  ([ADR-0007](adr/0007-system-scope-copies.md), [ADR-0008](adr/0008-tree-sitter-structural-editing.md))
- **A resource model with a 3-way diff** drives plan, apply, status and removal.
  ([ADR-0009](adr/0009-three-way-diff-resource-model.md))
- **Removal is configurable** per spec. The policy is saved at apply time.
  ([ADR-0011](adr/0011-removal-policy-recorded-at-apply.md))
- **Generations are git commits plus recorded state.** Rollback goes through a git worktree.
  ([ADR-0010](adr/0010-git-based-generations.md))
- **Order of work:** the core config manager first, then packages, then the extras.
  ([ADR-0012](adr/0012-core-first-roadmap.md))

---

## 5. Design-space analysis

Each subsection compares the options discussed in the interview and states the choice.

### 5.1 Configuration language

| Option | Pros | Cons |
|---|---|---|
| Custom syntax with its own parser | Most readable; could have a tree-sitter grammar for editors | A parser, error messages and tooling to write; Lua would still be needed for logic |
| **Lua-embedded DSL (chosen)** | No parser to write; full language for per-host logic; sol2 already chosen; known from lazy.nvim | Readability depends on API design; needs sandboxing |
| An existing config language (KDL / HCL) | Existing parser | Still needs logic; two languages to learn |

The author added one constraint: the DSL must **not modify Lua syntax.** Clauses are ordinary
function calls that return tables. Metatable tricks don't count as syntax, but are kept to `dirs`
indexing.

### 5.2 Unit of configuration

| Option | Notes |
|---|---|
| **Module = package + files (chosen)** | Closest to the author's mental model, and close to home-manager's `programs.x` |
| NixOS-style typed options | Most powerful, but needs an option/type/merge system: high complexity |
| One flat manifest | Simple, but grouping is left to the user, which is today's problem |

The author made it stricter: **a spec owns at most one package.** A multi-package program (e.g.
Hyprland plus hyprpicker, hyprshot, cliphist) becomes one owning spec that `depends` on
package-only specs.

### 5.3 Deployment: symlink vs copy vs generated

- **Symlinks** keep edits made through `~/.config` in the repo and keep stow's familiar workflow.
- **Generated content** is needed for per-host values, e.g. the `font` and `cursor` variables in
  `Comtrya.yaml`.
- **Copies** are needed for apps that rewrite their own files (krita).

All three are kept as separate deployment kinds rather than forcing one model.

### 5.4 Templating vs structural editing

The author rejected find/replace templates. They proposed editing files through **tree-sitter
queries**, "like jq, but for any config format." The appeal:

- The base file stays a valid config that the app can read.
- An edit targets a syntactic node, not a text pattern.
- The same engine can serve as a standalone query tool.

The cost is the grammar dependency and the risk covered by RQ1.

### 5.5 Declarativeness of packages

The interview considered three positions:

- the manifests own every explicitly installed package (aconfmgr-style)
- mdot owns only the packages it installed itself
- mdot owns its own packages and warns about the rest

The author answered with an ownership rule (one spec ↔ one package) rather than a system-wide
policy. The removal behaviour is **configurable per spec, with a default.** System-wide ownership
is not adopted.

### 5.6 Generations: snapshots vs git

The interview considered three positions:

- files and the package set
- exact versions
- files only

The author proposed a **git-diff-based approach** instead: the repo history *is* the history.
mdot only needs to record which commit it applied and what it deployed. This avoids a content
store but raises RQ4.

### 5.7 How a diff works when files are symlinks

The author raised this question. If a deployed file is a symlink into the repo, a content diff
between "repo" and "live" is always empty. The resolution: mdot diffs **resources**, and for links
that means *existence and target*. Content history belongs to git, so `mdot status` shows both.
Whether this split is understandable in practice is RQ3.

---

## 6. Research questions

Each question is a claim the design depends on that hasn't been demonstrated yet.

**RQ1. Are tree-sitter edits reliable on real config files?**
The design assumes that querying a node, replacing its text, re-parsing and rejecting any ERROR
nodes is enough for safe edits. Unknowns:

- grammar availability for each format: kritarc (INI-like), waybar CSS, Hyprland Lua, kanata
  `.kbd` (no known grammar)
- whether whitespace and comments are preserved
- how hard it is to write queries by hand
- whether "exactly one match, else error" is too strict

**RQ2. Can one-spec-one-package ownership coexist with pacman on a rolling-release system?**
The design maps owned packages to *explicit* installs and depends-only packages to *dependency*
installs (`--asdeps`), and relies on pacman's own orphan tracking. Unknowns:

- packages that were already installed explicitly before mdot existed
- a package that one spec owns while another spec depends on it
- interaction with packages the author installs by hand
- AUR packages built from custom repos (e.g. `kanata-bin`)

**RQ3. Is a 3-way diff (desired × recorded × live) understandable and sufficient?**
The planner's decision table (design.md §9.2) has seven cases, including drift and modified-since-
deploy conflicts. Unknowns:

- whether the plan output is clear enough to act on
- whether `status` combined with `git status` makes the "content belongs to git" split obvious
- whether any real situations fall outside the table

**RQ4. Can rollback work when symlinks point into the live working tree?**
A link-based generation restores the *set* of links, but their content is whatever the working tree
currently holds. Options:

- check out the old commit (needs a clean tree)
- restore the link set only
- deploy old content as copies during rollback

None is clearly right. This is the design's weakest point. (Formerly Q5.)

**RQ5. Can spec loading be both pure and expressive enough?**
The sandbox removes `os.execute` and `io` so that `plan` has no side effects. Unknowns:

- whether real per-host logic needs more than `host`, `os`, `vars`, `env()` and `exists()`
- whether `enabled` needs to be lazy, e.g. depend on another spec's enabled state (formerly Q3)

**RQ6. Does the model cover the author's real dotfiles without escape hatches?**
This is checked by translating `~/dotfiles-v2` (Appendix A). Constructs that need new features are
recorded as findings rather than hidden.

---

## 7. Methodology: experiments

These are small, throwaway prototypes to run **before** Phase 1 is locked. Each answers one
research question and is judged by an explicit pass/fail criterion.

| ID | Answers | Experiment | Pass criterion |
|---|---|---|---|
| S1 | RQ1 | ~200-line C++ program linking tree-sitter with INI, CSS, JSON and Lua grammars that implements `set(query, value)` with re-parse validation, run against the real `kritarc`, waybar `style.css` and Hyprland Lua config | Edits produce a byte-identical file apart from the target node, and comments survive; a malformed edit is rejected |
| S2 | RQ1 | Write the queries the Appendix A examples need, by hand | Each query fits in about one line and the author finds it writable; if not, consider a higher-level helper per language |
| S3 | RQ2 | Shell-script prototype on a VM or container: install owned packages explicitly, depends with `--asdeps`, remove a spec, run the orphan query | Removal uninstalls exactly what is no longer referenced, and packages installed by hand are untouched |
| S4 | RQ3, RQ6 | Prototype loader + planner (links only) on a copy of `~/dotfiles-v2` translated per Appendix A, printing a plan | Plan output is readable; the edge cases in design.md §9.2 are each reproduced once |
| S5 | RQ4 | Try each rollback option on a fixture repo with three commits that change both the link set and file content | One option restores both link set and content without surprising the user, or the limitation is documented and accepted |
| S6 | RQ5 | Port the per-host parts of `nexos.yaml` and `tablet.yaml` to `enabled(...)` | No case needs I/O or side effects during loading |

The order is S1/S2 first (highest uncertainty, most novel), then S4, S5, and S3. Results go into §8
of this document, and decisions that come out of them go into new ADRs.

---

## 8. Evaluation criteria

mdot v1, meaning the core config manager (phases 1–4), is successful if it meets all of these:

1. **Expressiveness:** every construct in `~/dotfiles-v2` is either expressible or explicitly
   deferred to a planned phase (Appendix A).
2. **Purity:** `mdot plan` and `mdot status` never modify the filesystem. Testable by running them
   against a read-only `$HOME`.
3. **Idempotence:** `apply` followed by `plan` yields an empty plan.
4. **Removal:** deleting a spec and applying removes exactly its recorded resources, following the
   recorded `on_remove` policy.
5. **Drift detection:** a hand-retargeted link, a hand-edited rendered file and an un-applied patch
   are each reported by `status`.
6. **Safety:** no destructive operation happens without confirmation, unless the user's policy
   allows it. Ambiguous states stop with an error and never resolve silently.
7. **Rollback:** restores at least the link set and rendered files of generation N, per the outcome
   of RQ4.
8. **Structural editing:** results of S1 hold on the author's real files.

---

## 9. Limitations and future work

**Known limitations of the current design:**

- **Content rollback for symlinked files** is unresolved (RQ4).
- **Grammar coverage:** formats without a maintained tree-sitter grammar (kanata `.kbd`) can't use
  `render`/`patch`.
- **Single user:** `dirs.home` always means the invoking user. Multi-user and system-wide user
  configuration are deferred.
- **Arch only** in practice: other distros and OSes are interface-ready but unresearched. Each
  needs its own study of package-manager semantics.
- **Duplicate spec names are an error.** There's no override or extend mechanism for host-specific
  additions yet.
- **Unmanaged scripts** (`dotfiles-v2/unmanaged/`, `scripts/`) stay outside mdot until hooks exist.

**Future work, in roadmap order (design.md §13):**

- package providers (pacman)
- an AUR / PKGBUILD-from-git source that doesn't need paru to bootstrap
- hooks
- lockfile
- secrets
- systemd units, groups and users
- other platforms
- `pkg_alts` introspection in `mdot specs`

**Research not yet done:** a broader survey of dotfile managers beyond §3, which only covers tools
from the author's own experience and the earlier session's analysis.

---

## Appendix A: Translating `~/dotfiles-v2`

This appendix answers RQ6 on paper. It uses the spec syntax from design.md §5.

**`hyprland.yaml`.** The link plus a package list becomes one owning spec plus package-only specs:

```lua
-- specs/hyprland.lua
return {
  spec {
    name("hyprland"),
    depends("hyprpicker", "hyprshot", "cliphist", "awww"),
    config(dirs.home_config["hypr"]),
  },
  spec { name("hyprpicker") },
  spec { name("hyprshot") },
  spec { name("cliphist") },
  spec { name("awww") },
}
```

**`utils.yaml` / `dev-utils.yaml`.** The long tail of packages with no config is handled with plain
Lua:

```lua
-- specs/cli-tools.lua
local out = {
  spec { name("btop"),    config(dirs.home_config["btop"]) },
  spec { name("bat"),     config(dirs.home_config["bat"]) },
  spec { name("mpv"),     config(dirs.home_config["mpv"]) },
  spec { name("github-cli"), config(dirs.home_config["gh/config.yml"]) }, -- file-level: gh writes hosts.yml itself
}
for _, p in ipairs { "eza", "zoxide", "fzf", "wget", "rsync", "tldr", "unzip", "zip" } do
  out[#out + 1] = spec { name(p) }
end
return out
```

Two more cases:

- clangd's config without its package (the package line is commented out in comtrya) becomes
  `name("clangd", { pkg = false })`.
- `.inputrc` becomes `spec { name("inputrc", { pkg = false }), config(dirs.home[".inputrc"]) }`.

**`modules/bash`.** Repo files whose names differ from the target, and several target paths:

```lua
return spec {
  name("bash"),
  config(dirs.home_config["bash"]),
  config(dirs.home[".bashrc"],       { from = "configs/bash/bashrc.sh" }),
  config(dirs.home[".bash_profile"], { from = "configs/bash/bash_profile.sh" }),
}
```

**`modules/krita`.** comtrya uses `walk_dir` into `~/.config`, and krita rewrites its own `kritarc`:

```lua
return spec {
  name("krita"),
  config(dirs.home_config["kritashortcutsrc"]),
  patch(dirs.home_config["kritarc"], { lang = "ini", edits = {
    set(q[[(setting (setting_name) @k (#eq? @k "canvasState") (setting_value) @v)]], "OPENGL_SUCCESS"),
  } }),
}
```

The krita keys are illustrative. Which queries are actually needed is S2.

**`Comtrya.yaml` variables.** These become `vars` + `render`:

```lua
-- config.lua
return {
  vars = { font = "Hack Nerd Font", cursor = { name = "phinger-cursor-dark", size = 16 } },
  defaults = { on_remove = { files = "remove", package = "ask" } },
}
```

```lua
-- specs/waybar.lua
return spec {
  name("waybar"),
  depends("ttf-hack-nerd"),
  config(dirs.home_config["waybar/config.jsonc"]),
  render(dirs.home_config["waybar/style.css"], {
    base = "templates/waybar/style.css", lang = "css",
    edits = { set(q[[(declaration (property_name) @p (#eq? @p "font-family") (plain_value) @v)]], vars.font, { all = true }) },
  }),
}
```

**`modules/kanata`, `tablet.yaml`, `phinger-cursors.yaml`, `paru.yaml`.** These are AUR packages,
some built from a custom git repo (`NexushasTaken/kanata-bin`). Until then, only their configs can
be expressed. Their package source waits for the AUR phase. kanata's uinput group/udev setup needs
system scope (files) and account management (groups, deferred).

**`nexos.yaml`.** Its `depends` list of modules and fonts becomes `enabled(host.name == "nexos")` on
host-specific specs. Package-only specs cover the fonts and misc packages.

**Findings:**

1. Two additions to `config()` came out of this translation:
   - `walk`: link files individually, for `.cargo` and krita
   - `from`: a repo name that differs from the target name, for bash
2. AUR, groups and hooks are the only deferred constructs.
3. Nothing in dotfiles-v2 is silently unrepresentable.
