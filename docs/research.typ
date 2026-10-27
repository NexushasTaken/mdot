#import "template.typ": *

#show: paper.with(
  title: "mdot: A Declarative, Package-Scoped Dotfile Manager",
  subtitle: "Research document",
  meta: [Working draft · 2026-10-06],
  abstract: [
    Existing dotfile managers sit at two extremes. Some only place files: GNU stow, and the
    author's previous mdot design. Others are general machine provisioners, like comtrya, that have
    no idea that a config file belongs to a package. Neither tracks what it deployed, so neither can
    reliably remove things or detect drift. mdot proposes a middle path:

    - A *plain-Lua, package-scoped spec format* where each spec owns at most one package and that
      package's configuration.
    - A *resource model with a 3-way diff* (desired × recorded × live) that makes plan, drift
      detection and removal first-class.
    - *Git-based generations* for rollback.
    - *Tree-sitter-based structural editing* to change config files without a text templating
      language.

    The scope is ambitious. This document narrows it into testable research questions and small
    experiments to run before the architecture is committed to.
  ],
)

This is the research companion to `design.typ`, which holds the current spec, and `adr/`, which
records individual decisions. It explains why mdot exists, what it claims, which claims are still
unproven, and how they will be tested. Everything here comes from the design interview and from
inspecting the author's existing setups (`~/dotfiles-v2`, the comtrya fork at `~/dev/repos/comtrya`,
and the older Yolk setup at `~/dotfiles-yolk`) and an earlier design session log. The only outside
research is a narrow web search for prior art on the 3-way diff (@prior-art-3way). A broad survey has
not been done yet; @limitations lists that as future work.

= Introduction and motivation <intro>

== The author's setup today

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

== The setup before it: Yolk <yolk-setup>

`~/dotfiles-yolk` is the author's previous generation. By commit dates the tools ran in this order:
GNU stow (the `unmanaged/` directory), Yolk (52 commits, 2025-12-07 to 2026-03-20), then comtrya
(`~/dotfiles-v2`, 65 commits, from 2026-03-30). The author moved away from Yolk, so how it was used
and where it fell short is evidence for mdot, the same as dotfiles-v2.

*Layout.* One `yolk.rhai` at the repo root declares 19 _eggs_ (one per program, 18 enabled), and each
egg is a directory under `eggs/`:

```rhai
bash: #{
  enabled: true,
  targets: #{ "bashrc.sh": "~/.bashrc", "bash_profile.sh": "~/.bash_profile", ".": "~/.config/bash" },
},
gh: #{
  enabled: true, strategy: "merge", targets: "~/.config/gh",
  unsafe_shell_hooks: #{ pre_deploy: "./bin/gh/pre_deploy.sh", post_undeploy: "./bin/gh/post_undeploy.sh" },
},
```

An egg maps a repo directory (or individual files) to one or more targets. It has an `enabled` flag,
an optional `strategy` (`merge` for `home` and `gh`) and optional shell hooks. This is already the
shape of an mdot spec without packages.

*Variables and templating.* A `data` table holds `git.name`, `git.email`, `font` and `cursor`. Five
files in four eggs (`git`, `alacritty`, `hypr`, `uwsm`) carry comment markers that the tool
evaluates, for example:

```
  email = "nexushastaken@gmail.com" # {< replace_quoted(data.git.email) >}
# {# replace_number(data.cursor.size) #}
export XCURSOR_SIZE=16
```

The marker sits in a comment, so the file stays valid for the program whether or not Yolk has run.
The repo file holds the already-rendered value. This is the idea `render`/`patch` took from Yolk
(@related), and the `data` table is the origin of the `font` and `cursor` variables in
`Comtrya.yaml` and of the planned `config {...}` clause (git name and email).

*Packages and everything else are a shell script.* The `home` egg has one `post_deploy` hook,
`bin/archlinux.sh`. It holds a flat array of 37 official packages, one AUR package, two custom
bootstrap steps (`paru` from the AUR, `kanata-bin` from the author's own git repo), service enabling
(`systemctl --user enable` for four units) and a download (below). `bin/utils.sh` (228 lines)
re-implements what a package provider would do: "is it installed", `pacman -S --needed`, and picking
`paru` or `yay`. Idempotence comes from checks like `pacman -Q` and `command -v`.

*Downloads.* There are two real fetches. They are the first concrete use cases for `net.download`:

#table(
  columns: (auto, 1fr, 1fr),
  [What], [How it is done today], [What it needs],
  [phinger-cursors theme],
  [`wget` of `releases/latest/download/phinger-cursors-variants.tar.bz2` into `~/.cache/yolk`, then
    `tar xvfj` into `~/.local/share/icons`. Skipped if `phinger-cursors-*` already exists there.],
  [Archive extraction into a directory. The URL points at `latest`, so it is not reproducible and
    cannot have a fixed hash. An AUR package for it also exists (`phinger-cursors.yaml` in v2).],
  [kanata binary (in `unmanaged/`)],
  [`wget` of `releases/download/v1.9.0/kanata` into `~/.local/bin/kanata`, then `chmod +x`. Skipped
    if the file is executable. Later replaced by the `kanata-bin` AUR package.],
  [A single file, an executable mode, a pinned version. A fixed hash is possible here.],
)

Nothing is verified: no checksum, no signature. `unmanaged/install.sh` adds a retry loop (3 seconds
between attempts) around `wget -c`. Both downloads were later covered by a package, so the evidence
for a download clause is two cases, each of which the author has already worked around.

*What was never migrated.* `unmanaged/` still holds the stow-era configs: 31 entries under `.config` (i3, sway,
polybar, picom, rofi, mpv, kitty, …), plus `.xinitrc`, `.Xresources`, `.gtkrc-2.0` and others. It also holds an `install.sh` that clones four git repositories (two GTK/icon themes
with their own `./install.sh`, a tmux plugin, one more theme), sets up the `uinput` group and a
udev rule for kanata, and copies a unit file to `/etc/systemd/system`. That is the same content as
the part of dotfiles-v2 that needs system scope, groups and hooks (@translation).

*What Yolk lacked,* as the author's setup shows it:

+ *No link between an egg and its package.* The egg list and the package array are separate, so
  adding a program means editing two places in two languages. This is problem 1 (@problems) again,
  with the package side moved into a shell script.
+ *Packages, services and downloads are imperative.* They run in a hook and are not recorded, so
  nothing can plan them, show a diff or remove them (problem 2).
+ *No per-machine variation.* `yolk.rhai` has one global `data` table and no host logic. The
  per-host files (`nexos.yaml`, `tablet.yaml`) appear only in dotfiles-v2.
+ *Hooks do filesystem bookkeeping.* The `gh` egg uses `pre_deploy` to `mkdir ~/.config/gh` and
  `post_undeploy` to `rmdir` it, so Yolk needs a hook for what a deploy tool could do itself.
+ *The migration stalled.* Dozens of configs never left `unmanaged/`. Some of them (waybar, hypr)
  also exist as eggs, so it is unclear which copy is current. This is evidence for keeping the first
  version small enough to finish a translation (@scope).

== Observed problems <problems>

The interview identified four problems:

+ *The unit is wrong.* The real relationship is "this config belongs to this package", but the tool
  models it as two unrelated actions glued together with `before:`. Every config pays that verbosity
  cost.
+ *No removal or drift tracking.* Deleting a manifest entry leaves its link and package behind, and
  nothing reports that the system has drifted from the repo.
+ *Packages that aren't in the official repos are hacky.* AUR installs go through a Lua plugin
  (`plugins/aur.lua`) that shells out to `makepkg`. Bootstrapping `paru` is itself a plugin
  invocation (`paru.yaml`).
+ *Weak plan, error and dry-run output.* It's hard to know beforehand what will happen, or
  afterwards what did happen.

== Evidence from the comtrya fork

The fork's commits (`ec46d076..a5b400f8`) show what the author already had to add:

- `before` / `after` hooks on actions (`f42ed59`, fixed in `3fc1973`)
- continuing after a failed action (`6ecdc02`)
- an `interactive` key for `command.run` (`03a8e72`)
- switching the Arch provider to `pacman` (`838cae0`)
- printing an action's summary before it runs (`dc9d3c5`)
- more directories in the user context (`a5b400f8`)

The tool needed patching for ordering, failure handling and output, which are core behaviours. That
is the strongest sign that extending comtrya further won't fix the underlying model.

== Abandoned direction

The repository's first plan (`archive/comtrya-port-plan.md`) was a 1:1 C++ port of comtrya. Porting
would keep comtrya's model, which is the source of problems 1 and 2, so the port was dropped in
favour of a fresh design. Its technology choices were kept (ADR-0001, ADR-0002).

= Problem statement and scope <scope>

*Problem.* Give one user a way to declare, in a version-controlled repo, which programs they use and
how each is configured. Then reconcile a machine to that declaration, including removing what is no
longer declared, and do it with predictable, previewable and reversible steps.

*In scope.* The core research target, per the interview:

- user-level and system-level configuration files
- per-machine variation
- plan / apply / status / adopt
- removal policies
- rollback
- structural editing of config files

*Designed for, implemented later:*

- package management (pacman first)
- AUR sources
- hooks
- lockfile

*Out of scope for now:*

- user and group account management
- multi-user / system-wide user configuration
- secrets
- non-Arch backends

The interfaces are meant to be generic, with Arch as the first implementation; porting to other OSes
is deferred research.

*Non-goals,* from the stated philosophy:

- mdot will not ship knowledge of any program's config location or package names.
- It will not guess when something is ambiguous.
- It will not perform destructive actions silently.

= Related work <related>

This comparison is limited to tools the author has used or analysed in the earlier design session.

#{
  set text(size: 8.5pt)
  table(
    columns: (1fr, 1fr, 1fr, 1fr, 0.8fr, 0.9fr, 2.6fr),
    [Tool], [Config], [Deploy], [Templating], [Packages], [Lockfile], [Relevance to mdot],
    [GNU Stow], [directory structure], [symlink], [no], [no], [no],
    [Its symlink model is kept, but it has no idea of packages, which is why the author left it.],
    [comtrya], [YAML manifests], [copy / link / run actions], [Tera strings], [yes, multiple OSes],
    [no],
    [General provisioner. It has a package concept, but packages and configs are unrelated actions
      with no state (@problems). The project was reportedly rewritten mid-2026, a warning against
      depending on niche tools.],
    [Yolk], [Rhai], [symlink + inline edits], [inline comment markers], [no], [no],
    [Used by the author for about four months (@yolk-setup). Its config files stay valid whether or
      not the tool has processed them. That idea influenced `render`/`patch`. It has no package
      concept and no per-machine logic; packages lived in a shell hook.],
    [Nix + home-manager], [Nix expressions], [symlinks into an immutable store],
    [declarative options], [yes], [yes (`flake.lock`)],
    [The model mdot wants (declarative, generations, rollback), but with heavy infrastructure. mdot
      aims for the semantics without the store.],
    [lazy.nvim], [Lua tables], [git clone], [no], [plugin-scoped], [yes (`lazy-lock.json`)],
    [The source of the spec style: spec files in a folder that are merged automatically, plus a
      lockfile.],
    [mdot.old (author's prior design)], [Lua tables (`init.lua`)], [stow-like symlinks], [no], [no],
    [no],
    [It had `depends`, `enabled`, `platforms` and `excludes`. Unresolved problems: how `depends` and
      `enabled` interact, empty System/Project scopes, and the awkward `excludes = "*"` double
      negative.],
  )
}

*The gap.* No tool in this table combines:

- package-scoped ownership (config ↔ package)
- recorded deployment state, which enables removal and drift detection
- low infrastructure (just a binary and a git repo)

mdot targets that combination.

== Prior art for the 3-way diff <prior-art-3way>

A web search on 2026-10-23 asked one question: is there a library mdot could use for the 3-way diff
(@rqs, RQ3) instead of writing its own planner? Unlike the table above, this looks at tools the
author has not used. It is a narrow search, not the broad survey in @limitations.

*Result: no C or C++ library was found.* The libraries that exist, in other languages, cover only
the generic loop: for each item, call create, update or delete. What "matches" means for a resource
kind, and what to record so it can be recognised later, stays with the caller.

#{
  set text(size: 8.5pt)
  table(
    columns: (auto, auto, 2fr, 1.4fr),
    [Tool], [Language], [What it does], [Relevance to mdot],
    [optative (0.1.x)], [Rust],
    [The caller gives a desired set and create/update/delete hooks. It diffs the desired set against
      what it tracked on the previous run. Its docs show no ownership, conflict or drift handling, and
      it does not read the live system; the hooks do.],
    [Covers the loop only, not the part that protects files.],
    [kreconciler], [Go], [A library for control loops outside Kubernetes.],
    [The loop only, no diff logic.],
    [Linx (`Linx.Netlink.Rtnl.Diff`)], [Elixir],
    [Reconciles Linux network state. Inputs: desired, observed, and the set of keys it installed on
      an earlier pass. It deletes an item only if it installed it and the item is no longer desired;
      anything else is left alone. Its docs compare this to `kubectl apply`'s last-applied
      configuration. For routes, where the kernel tags who created each one, it uses a two-way diff
      instead. The owned set is kept in memory, not persisted.],
    [The same structure as mdot's design, arrived at independently. Not usable from C++.],
    [chezmoi], [Go],
    [Dotfile manager. `chezmoi status` has two columns: the last state chezmoi wrote vs the actual
      state, and the actual state vs the target state.],
    [The same three inputs. How it stores and compares the entries was not checked.],
    [Elektra `ThreeWayMerge`], [C++],
    [Only an API page was found. It appears to merge configuration, not reconcile deployed state.],
    [Not applicable, not checked further.],
  )
}

*Findings:*

+ mdot writes its own planner. The generic part is small; the part specific to each resource kind
  is the design itself (`design.typ`, "The 3-way diff").
+ mdot's three inputs and its deletion rule ("only what mdot recorded, and only if unchanged") match
  Linx and `kubectl apply`, and appear to match chezmoi.
+ Linx's two-way case matches a property of links: a symlink's target already shows whether it
  points into the repo. For links, the record mostly matters for removal and for the parent
  directories mdot created.
+ For later reading, useful search terms are "three-way diff last-applied" and "reconciler
  ownership". The Linx page is short and explains the pattern clearly.

*Sources:*

- optative: #link("https://docs.rs/crate/optative/0.1.4/source/README.md")
- kreconciler: #link("https://beta.pkg.go.dev/github.com/koyeb/kreconciler")
- Linx: #link("https://linx.hexdocs.pm/Linx.Netlink.Rtnl.Diff.html"),
  #link("https://linx.hexdocs.pm/reconcile-overview.html")
- chezmoi: #link("https://chezmoi.io/reference/commands/status"),
  #link("https://chezmoi.io/reference/concepts/")
- Elektra: #link("https://doc.libelektra.org/api/0.8.7/html/threewaymerge_8cpp.html")

= Design overview <overview>

`design.typ` is the authoritative spec; the decisions are in `adr/`. In summary:

- *Specs are plain Lua,* lazy.nvim-style, with no syntax extensions. Each spec owns at most one
  package. Other packages are only referenced via `depends`. (ADR-0003, ADR-0005)
- *Spec files are auto-merged* from `specs/**/*.lua`. Mirror directories (`configs/`, `home/`,
  `system/etc/`, …) hold the files. (ADR-0004)
- *Per-machine variation* uses ordinary Lua expressions in `enabled(...)`. (ADR-0006)
- *Four deployment kinds:* `config` (symlink), `render` (base file + edits → copy), `patch` (enforce
  parts of an app-owned file), and `sysfile` (root-owned copy). (ADR-0007, ADR-0008)
- *A resource model with a 3-way diff* drives plan, apply and removal. (ADR-0009; no `status` command, ADR 0064)
- *Removal is configurable* per spec. The policy is saved at apply time. (ADR-0011)
- *Generations are git commits plus recorded state.* Rollback goes through a git worktree.
  (ADR-0010)
- *Order of work:* the core config manager first, then packages, then the extras. (ADR-0012)

= Design-space analysis <design-space>

Each subsection compares the options discussed in the interview and states the choice.

== Configuration language

#table(
  columns: (auto, 1fr, 1fr),
  [Option], [Pros], [Cons],
  [Custom syntax with its own parser],
  [Most readable; could have a tree-sitter grammar for editors],
  [A parser, error messages and tooling to write; Lua would still be needed for logic],
  [*Lua-embedded DSL (chosen)*],
  [No parser to write; full language for per-host logic; sol2 already chosen; known from lazy.nvim],
  [Readability depends on API design; needs sandboxing],
  [An existing config language (KDL / HCL)], [Existing parser],
  [Still needs logic; two languages to learn],
)

The author added one constraint: the DSL must *not modify Lua syntax.* Clauses are ordinary function
calls that return tables. Metatable tricks don't count as syntax, but are kept to `dirs` indexing.

== Unit of configuration

#table(
  columns: (auto, 1fr),
  [Option], [Notes],
  [*Module = package + files (chosen)*],
  [Closest to the author's mental model, and close to home-manager's `programs.x`],
  [NixOS-style typed options],
  [Most powerful, but needs an option/type/merge system: high complexity],
  [One flat manifest], [Simple, but grouping is left to the user, which is today's problem],
)

The author made it stricter: *a spec owns at most one package.* A multi-package program (e.g.
Hyprland plus hyprpicker, hyprshot, cliphist) becomes one owning spec that `depends` on package-only
specs.

== Deployment: symlink vs copy vs generated

- *Symlinks* keep edits made through `~/.config` in the repo and keep stow's familiar workflow.
- *Generated content* is needed for per-host values, e.g. the `font` and `cursor` variables in
  `Comtrya.yaml`.
- *Copies* are needed for apps that rewrite their own files (krita).

All three are kept as separate deployment kinds rather than forcing one model.

== Templating vs structural editing

The author rejected find/replace templates. They proposed editing files through *tree-sitter
queries*, "like jq, but for any config format." The appeal:

- The base file stays a valid config that the app can read.
- An edit targets a syntactic node, not a text pattern.
- The same engine can serve as a standalone query tool.

The cost is the grammar dependency and the risk covered by RQ1.

== Declarativeness of packages

The interview considered three positions:

- the manifests own every explicitly installed package (aconfmgr-style)
- mdot owns only the packages it installed itself
- mdot owns its own packages and warns about the rest

The author answered with an ownership rule (one spec ↔ one package) rather than a system-wide
policy. The removal behaviour is *configurable per spec, with a default.* System-wide ownership is
not adopted.

== Generations: snapshots vs git

The interview considered three positions:

- files and the package set
- exact versions
- files only

The author proposed a *git-diff-based approach* instead: the repo history _is_ the history. mdot
only needs to record which commit it applied and what it deployed. This avoids a content store but
raises RQ4.

== How a diff works when files are symlinks

The author raised this question. If a deployed file is a symlink into the repo, a content diff
between "repo" and "live" is always empty. The resolution: mdot diffs *resources*, and for links
that means _existence and target_. mdot does not track linked content, and `mdot plan` shows
only mdot's resources (ADR 0031, ADR 0064). Whether this split is understandable in practice is RQ3.

= Research questions <rqs>

Each question is a claim the design depends on that hasn't been demonstrated yet.

#let rq(id, title, body) = block(above: 1.2em)[*#id. #title* \ #body]

#rq("RQ1", "Are tree-sitter edits reliable on real config files?")[
  The design assumes that querying a node, replacing its text, re-parsing and rejecting any ERROR
  nodes is enough for safe edits. Unknowns:

  - grammar availability for each format: kritarc (INI-like), waybar CSS, Hyprland Lua, kanata
    `.kbd` (no known grammar)
  - whether whitespace and comments are preserved
  - how hard it is to write queries by hand
  - whether "exactly one match, else error" is too strict

  *Partly answered (S1/S2, @results-s1):* edits do preserve every byte outside the target node,
  comments included, and "exactly one match" was useful rather than too strict. But real files
  already have parse errors, the re-parse misses many bad values, and hand-written queries need the
  parsed tree in front of you. Open questions are in @results-open.
]

#rq("RQ2", "Can one-spec-one-package ownership coexist with pacman on a rolling-release system?")[
  The design (ADR 0027, ADR 0028) installs every package as _explicit_ and never edits pacman's
  install reason. mdot records which packages _it_ installed, and only those can be proposed for
  removal, once no reachable spec names them. Only the first group below needs an experiment.

  *Settled on paper, S3 confirms:*

  - packages that were already installed before mdot existed (ADR 0028: `present`, never removed)
  - packages the author installs by hand, including ones that depend on a package mdot wants to
    remove (`pacman -R` refuses; mdot must report it, not force it)

  *Settled on paper, nothing to test:*

  - a package that one spec owns while another spec requires it (an extra edge; removal needs zero
    referrers)

  *Decided:*

  - mdot-installed packages appear in `pacman -Qe`. This is accepted (ADR 0028).

  *Deferred to Phase 6+:*

  - AUR packages built from custom repos (e.g. `kanata-bin`)
]

#rq("RQ3", "Is a 3-way diff (desired × recorded × live) understandable and sufficient?")[
  The planner's decision tables (`design.typ`, "The 3-way diff") have seven generic cases and eleven
  for links (ADR 0030), including drift and modified-since-deploy conflicts. Unknowns:

  - whether the plan output is clear enough to act on
  - whether users understand that edits made through a link are not reported (ADR 0031)
  - whether any real situations fall outside the table
]

#rq("RQ4", "Can rollback work when symlinks point into the live working tree?")[
  A link-based generation restores the _set_ of links, but their content is whatever the working
  tree currently holds. Options:

  - check out the old commit (needs a clean tree)
  - restore the link set only
  - deploy old content as copies during rollback

  None is clearly right. This is the design's weakest point.
]

#rq("RQ5", "Can spec loading be both pure and expressive enough?")[
  The sandbox removes `os.execute` and `io` so that `plan` has no side effects. Unknowns:

  - whether real per-host logic needs more than `host`, `os`, `vars`, `env()` and `exists()`
  - whether `enabled` needs to be lazy, e.g. depend on another spec's enabled state

  *Answered (ADR 0013):* no live-state helpers. `env()` and `exists()` are dropped; per-host logic
  goes through `hosts/` (ADR 0019) and what mdot hands the spec.
]

#rq("RQ6", "Does the model cover the author's real dotfiles without escape hatches?")[
  This is checked by translating `~/dotfiles-v2` and `~/dotfiles-yolk` (@translation). Constructs
  that need new features are recorded as findings rather than hidden.
]

= Methodology: experiments <experiments>

These are small, throwaway prototypes to run *before* Phase 1 is locked. Each answers one research
question and is judged by an explicit pass/fail criterion.

#{
  set text(size: 9pt)
  table(
    columns: (auto, auto, 1fr, 1fr),
    [ID], [Answers], [Experiment], [Pass criterion],
    [S1], [RQ1],
    [\~200-line C++ program linking tree-sitter with INI, CSS, JSON and Lua grammars that implements
      `set(query, value)` with re-parse validation, run against the real `kritarc`, waybar
      `style.css` and Hyprland Lua config],
    [Edits produce a byte-identical file apart from the target node, and comments survive; a
      malformed edit is rejected],
    [S2], [RQ1], [Write the queries the @translation examples need, by hand],
    [Each query fits in about one line and the author finds it writable; if not, consider a
      higher-level helper per language],
    [S3], [RQ2],
    [Shell-script prototype on a VM or container that mimics the ADR 0028 record. Install package A
      by hand. "Apply" a spec set naming A and B (install only what is missing, write a state file
      of what was installed). Then drop the specs, install C by hand, make an outside package
      depend on B, and delete the state file in a copy of the setup],
    [After dropping the specs, the only removal candidate is B. A and C are untouched. Removing B
      with `pacman -R` fails cleanly while the outside dependent exists. With the state file lost,
      nothing is proposed],
    [S4], [RQ3, RQ6],
    [Prototype loader + planner (links only) on a copy of `~/dotfiles-v2` translated per
      @translation, printing a plan],
    [Plan output is readable; the edge cases in the design's 3-way diff table are each reproduced
      once],
    [S5], [RQ4],
    [Try each rollback option on a fixture repo with three commits that change both the link set
      and file content],
    [One option restores both link set and content without surprising the user, or the limitation
      is documented and accepted],
    [S6], [RQ5], [Port the per-host parts of `nexos.yaml` and `tablet.yaml` to `enabled(...)`],
    [No case needs I/O or side effects during loading],
  )
}

The order is S1/S2 first (highest uncertainty, most novel), then S4, S5, and S3. Results go into
@results, and decisions that come out of them go into new ADRs.

= Results <results>

== S1 and S2: tree-sitter editing (2026-10-25) <results-s1>

*Setup.* Claude ran S1 and S2 together as a throwaway Rust spike outside the repo, not as the
C++ program the table above describes (mdot moved to Rust, ADR 0036). Versions: `tree-sitter` 0.27.1,
grammars `tree-sitter-ini` 1.4.0, `-css` 0.25.0, `-json` 0.24.8, `-lua` 0.5.0, `-toml-ng` 0.7.0,
`-yaml` 0.7.2. The spike implements the engine as `design.typ` describes it ("Tree-sitter engine"): parse,
query, splice the captured byte ranges in reverse order, re-parse, check for errors. It ran
against copies of the author's live `~/.config/kritarc` (719 lines), waybar `style.css` and
`config.jsonc`, and Hyprland `configs/misc.lua` and `configs/autostart.lua`. TOML and YAML were
tested only on small made-up samples, because the author has no real files in those formats in scope.

*How an edit works,* because the spec doesn't spell it out. Tree-sitter turns the file into a tree
in which every node knows its start and end byte. For kritarc, `canvasState=OPENGL_SUCCESS` is a
`setting` node with two children, `setting_name` and `setting_value`. A query picks a node, the
engine replaces that node's bytes in the original text, and the result is parsed again to check it.
Tree-sitter never writes the file and never prints a tree back to text. It only says _where_ to
cut. That is why everything outside the edited node, comments and whitespace included, stays as it
was.

*What worked:*

#table(
  columns: (1.3fr, 1fr),
  [Check], [Result],
  [`set` on kritarc `canvasState`, Lua `font_family` and `local cursor_size`, JSON `spacing`, TOML,
    YAML], [Every other byte identical],
  [Applying the same edit to its own output, or the desired value to the live file],
  [No change (idempotent)],
  [Text predicates (`#eq?`)], [Evaluated by the Rust binding],
  [A query with a misspelt node, a syntax error or an unknown field],
  [Rejected when the query is compiled, with row and column, so `q[[...]]` can be checked at load
    time],
  [A query matching two nodes (`spacing` exists at the top level and inside `tray`)],
  [Rejected, as the strictness rule in ADR 0008 wants],
  [Cost: parse, query, edit and re-parse on the 28 KB kritarc], [About 6 ms per edit],
)

*What failed, most serious first:*

+ *Real files already contain parse errors.* kritarc uses KDE's `Key[$e]=value` flag (lines 654,
  683), which the INI grammar doesn't know. waybar's `config.jsonc` has trailing commas (lines 102,
  121), which waybar accepts and `tree-sitter-json` doesn't. `style.css` and both Lua files parse
  cleanly. With the rule in `design.typ` ("any ERROR node, nothing is written"), mdot could never
  edit kritarc or `config.jsonc`. The spike instead compared error counts ("the edit adds no new
  errors"), which let the edits through. A count is a weak check: an edit that removes one error
  and adds another would pass. This is not a decided rule.

+ *Keys near a parse error disappear, and `ensure` duplicates them.* Error recovery after
  `File1[$e]=` swallowed the next keys (`Name1`, `maxRecentFileItems`) into the ERROR node. A query
  for `maxRecentFileItems` returns zero hits. `set` then fails safely ("matched nothing"), but
  `ensure` reads zero hits as "missing" and inserts a second `maxRecentFileItems=` line. The
  re-parse doesn't notice. This is silent corruption.

+ *Re-parsing does not catch bad values.* Grammars are built to tolerate broken input, so many wrong
  edits still parse:

  #table(
    columns: (1fr, auto),
    [Edit (value inserted as raw text)], [Re-parse],
    [JSON number := empty, or := unquoted `Hack Nerd Font`], [caught],
    [Lua string content := `a"b`], [caught],
    [YAML value := `a: b`], [caught],
    [JSON pair inserted without its comma], [caught],
    [CSS string content := `a"b`], [*not caught*],
    [CSS string content := a value that closes the rule and starts a new one], [*not caught*],
    [CSS `font-family: 12` (wrong type, valid syntax)], [*not caught*],
    [INI value containing a newline: adds a new key], [*not caught*],
    [Lua string content := `x" .. os.getenv("HOME") .. "`: Hyprland would run it],
    [*not caught*],
  )

  The re-parse is a syntax check only, and an incomplete one. Whether values are inserted raw or
  encoded for the target language is not in the spec (@results-open).

+ *The example queries in this document were wrong.* The waybar query in @translation captures
  `plain_value`. On the real `style.css` (`font-family: "Noto Sans", sans-serif;`) it matched
  `sans-serif`, not the font: a quoted font is a `string_value` with a `string_content` child. An
  unquoted `Hack Nerd Font` is three `plain_value` nodes, so `all = true` would edit one word at a
  time. A query that works is
  `(declaration (property_name) @p (#eq? @p "font-family") . (string_value (string_content) @v))`.
  The krita query in @translation worked unchanged.

+ *`ensure` and inserts leave syntax to the user.* Adding a key to a JSON object needs the comma
  written by hand (`",\n  \"exclusive\": true"`), and a Lua field needs its comma and indentation.
  Leaving them out was rejected by the re-parse for JSON. `ensure` was idempotent once the text was
  right.

*S2: writing queries.* Claude wrote the queries, not the author, so the pass criterion ("the author
finds it writable") is not judged yet. What was measured: none of the working queries could be
written without first dumping the parsed tree, because node names differ per grammar (`setting_name`,
`property_name`, `string_content`, `block_mapping_pair`). Unscoped queries fit on one line. Scoped
ones (a key inside a section, table or object) were 110 to 270 characters.

*A key-path helper,* the fallback the S2 row names. The spike tried a small per-language function
that _generates_ the query from a key path, so the engine stays the same underneath:

#table(
  columns: (auto, 1fr, auto),
  [Lang], [Path], [Generated query],
  [ini], [`{"canvasState"}` (key before any section)], [81 chars],
  [ini], [`{"GradientChooser", "global/viewMode"}`], [137 chars],
  [json], [`{"tray", "spacing"}` (anchored at the document root)], [172 chars],
  [lua], [`{"misc", "font_family"}`], [145 chars],
  [css], [`{"*", "font-family"}` (replaces the whole declaration)], [107 chars],
)

All five edited the right node on the real files. A helper that knows the language can also encode
the value (`a"b` becomes `"a\"b"` in JSON and Lua) and refuse values that have no encoding (a
newline in plain INI). Things the spike found that a helper has to deal with: CSS values are several
sibling nodes, so a path can only target the whole declaration; Lua configs wrap tables in calls such
as `hl.config({...})`, so Lua paths can't be anchored at the file root; INI keys before the first
section need their own form. Paths cover "change a value". They don't cover "insert this block
here", which still needs a raw query.

*Verdict against the pass criteria.* S1 passes the byte-identity part on all real files. It fails
"a malformed edit is rejected" in general: some are, many aren't (table above). S2 is open until the
author judges writability. The idea itself is feasible. The engine as specified is not safe enough
yet, for the reasons in failures 1 to 3.

== Open questions from S1/S2 <results-open>

Not decided. These are questions for a later decision (ADR), not answers.

+ *What does the user write: raw queries, key paths, or both?* Options seen: raw queries only (as
  `design.typ` has now); paths as the normal form with raw queries as an escape hatch; paths only.
+ *What happens when the target file already has parse errors?* Options seen: refuse to edit;
  allow only if no error is near the edited node; allow and warn. Whatever the choice, `ensure`
  must not insert when an ERROR node could be hiding the key (failure 2).
+ *Are values inserted raw or encoded per language?* Raw is what `design.typ` implies today and is
  what lets the injections in failure 3 through. Encoding needs a per-language encoder, which ties
  in with question 1.
+ *Which grammars cover the real files?* KDE's INI dialect (`[$e]`) and JSONC trailing commas are
  not handled by the stock grammars. Options: other grammars, patching the grammar, a user-supplied
  grammar (tested in @results-grammars), or living with the gaps.

== User-supplied grammars (2026-10-25) <results-grammars>

*Question* (the author's idea): can users add their own tree-sitter grammars when mdot's built-in
ones don't cover a format, the way Neovim does? `design.typ` currently says grammars are "vendored
and compiled in", so this would be a change to the design, not a detail.

*How Neovim does it,* from its own help (`:h treesitter`, Nvim 0.12.5). A parser is a compiled
shared library. Nvim searches `parser/{lang}.*` on the runtimepath (the first match wins, so a user
copy beats a bundled one) or takes an explicit path:
`vim.treesitter.language.add('python', { path = "/path/to/python.so" })`. The library exports a C
function `tree_sitter_<lang>()` that returns the grammar's tables, and `symbol_name` overrides that
name. `.wasm` parsers work only when Nvim is built with `ENABLE_WASMTIME`. nvim-treesitter is the
plugin that downloads grammar sources and compiles them into those `.so` files.

*Setup.* A second throwaway Rust spike, outside the repo: `tree-sitter` 0.27.1 plus `libloading` 0.8
for `dlopen`. Inputs: the author's own Neovim parsers in `~/.local/share/nvim/site/parser/`, and a
15-line custom grammar `kdeini` that accepts KDE's `[$e]` markers. Claude wrote that grammar, built
it with the `tree-sitter` CLI 0.26.9 (`generate`, then `build`) and, separately, with plain
`cc -shared -fPIC src/parser.c`.

*How loading works.* There are three steps: `dlopen` the file, look up the symbol
`tree_sitter_<name>`, then wrap the returned pointer as a `Language`. From there the engine is the
same as for a built-in grammar: same parser, same queries, same splice. The cost is about 10 lines
and three `unsafe` blocks. The library must stay loaded for as long as mdot runs, because the
`Language` points at static data inside it (in the generated `parser.c`, `tree_sitter_kdeini()`
returns the address of a `static const TSLanguage`). Unloading it while a tree exists would leave
a dangling pointer.

*What worked:*

#table(
  columns: (1.3fr, 1fr),
  [Check], [Result],
  [Neovim's `json.so` vs the `tree-sitter-json` crate, on waybar's `config.jsonc`],
  [Loads (ABI 14). Identical tree],
  [Neovim's `typst.so`, a grammar mdot would never bundle, with an external scanner (extra C code),
    on `research.typ` (44 KB)], [Loads, no parse errors],
  [Custom `kdeini` on the real kritarc], [0 parse errors (stock INI grammar: 2, lines 654 and 683)],
  [`set` on `File1[$e]` in `[RecentFiles]`, which the stock grammar hid inside an ERROR node],
  [Only that line changes. Setting the old value back gives a byte-identical file],
  [The same grammar built with plain `cc` instead of the CLI], [Same result],
  [A query using a node or field the custom grammar doesn't have],
  [Rejected when compiled, with row and column, as with built-in grammars],
  [Grammar built for ABI 14], [Accepted (this library takes ABI 13 to 15)],
  [Grammar claiming ABI 16 (a future CLI)],
  [Rejected by the parser with "Incompatible language version 16", no crash],
  [Missing file, a file that isn't a library, wrong symbol name],
  [Clear errors ("cannot open shared object file", "invalid ELF header", "undefined symbol:
    tree_sitter_ini")],
)

*What it showed beyond "it works":*

+ *Writing a grammar is real work, even for INI.* The first `kdeini` version left 34 parse errors
  in kritarc, because KDE also nests groups (`[MainWindow][DockWidget ...]`). One more rule fixed
  that. The error check is what found the bug, so a user's grammar is only as trustworthy as its
  results on their real files.
+ *A grammar is native code running inside mdot.* Loading a `.so` runs whatever C it contains, with
  mdot's permissions. The Lua sandbox (ADR 0013) is for purity, not security, so this doesn't break
  a promise the design makes. A crash in a grammar's external scanner, though, takes mdot down with
  it (not tested, it follows from running in-process). It matters more for system scope:
  `design.typ` rejects root-read configs that point into a user-writable repo as a
  privilege-escalation path, and the same reasoning applies if the root side of
  `sudo mdot --exec-plan` would ever load a user-writable grammar.
+ *Compiled grammars are per OS and CPU.* A `.so` built on Linux x86-64 doesn't load on macOS or
  Windows, and cross-platform is a stated goal. A dotfiles repo shared across machines would have to
  carry one build per platform, compile from source on each machine (which needs a C compiler
  there, as nvim-treesitter does), or use WASM.
+ *A grammar version is part of the result.* Queries name node types, so a grammar update that
  renames a node breaks a spec's queries. mdot would report that cleanly (the query is rejected at
  load), but it's another thing that can change under a spec. nvim-treesitter pins grammar
  revisions for the same reason.

*Not tested:*

- *WASM grammars.* From reading the `tree-sitter` 0.27.1 source: a `wasm` cargo feature pulls in
  `wasmtime-c-api` and adds `WasmStore::load_language(name, bytes)` and
  `Parser::set_wasm_store`. A `.wasm` file is portable across platforms and runs sandboxed, which
  answers points 2 and 3 above, at the cost of a WebAssembly runtime inside mdot. Building a
  `.wasm` with `tree-sitter build --wasm` downloads wasi-sdk (114 MB), and that download stalled
  here, so neither building nor loading one was tried.
- Windows and macOS (`libloading` covers `.dll` and `.dylib`, but nothing ran there).
- Grammars from sources other than Neovim's parser directory and the one Claude wrote.

*Verdict.* Feasible. Loading a user's compiled grammar works with little code, needs no change to
the engine, and fixed the KDE gap from S1 on the real file. The open parts are about policy, not
about whether it works.

*Open questions (not decided):*

+ *In what form does the user supply a grammar?* Options seen: a compiled library at a path (Nvim's
  `language.add`); grammar sources that mdot compiles and caches (nvim-treesitter); a `.wasm` file;
  more than one of these.
+ *Where do grammars live, and are they part of the dotfiles repo?* In the repo they travel with the
  specs but need per-platform builds (point 3). Outside it, a fresh machine can't apply until the
  grammar is installed.
+ *Can a user grammar override a built-in one with the same name* (Nvim: first on the runtimepath
  wins), or must it use a new name?
+ *Can grammars be loaded on the privileged side at all* (point 2)?

= Evaluation criteria <evaluation>

mdot v1, meaning the core config manager (phases 1–4), is successful if it meets all of these:

+ *Expressiveness:* every construct in `~/dotfiles-v2` and `~/dotfiles-yolk` is either expressible
  or explicitly deferred to a planned phase (@translation).
+ *Purity:* `mdot plan` never modifies the filesystem. Testable by running them
  against a read-only `$HOME`.
+ *Idempotence:* `apply` followed by `plan` yields an empty plan.
+ *Removal:* deleting a spec and applying removes exactly its recorded resources, following the
  recorded `on_remove` policy.
+ *Drift detection:* a hand-retargeted link, a hand-edited rendered file and an un-applied patch are
  each reported by `plan`.
+ *Safety:* no destructive operation happens without confirmation, unless the user's policy allows
  it. Ambiguous states stop with an error and never resolve silently.
+ *Rollback:* restores at least the link set and rendered files of generation N, per the outcome of
  RQ4.
+ *Structural editing:* results of S1 hold on the author's real files.

= Limitations and future work <limitations>

*Known limitations of the current design:*

- *Content rollback for symlinked files* is unresolved (RQ4).
- *Grammar coverage:* formats without a maintained tree-sitter grammar (kanata `.kbd`) can't use
  `render`/`patch`. Dialects the stock grammars don't handle (KDE INI `[$e]`, JSONC trailing commas)
  leave parts of a file unreachable (@results-s1). User-supplied grammars could close these gaps
  (@results-grammars). Not decided.
- *Single user:* `dirs.home` always means the invoking user. Multi-user and system-wide user
  configuration are deferred.
- *Arch only* in practice: other distros and OSes are interface-ready but unresearched. Each needs
  its own study of package-manager semantics.
- *Duplicate spec names are an error.* There's no override or extend mechanism for host-specific
  additions yet.
- *Unmanaged scripts* (`dotfiles-v2/unmanaged/`, `scripts/`) stay outside mdot until hooks exist.

*Future work, in roadmap order (`design.typ`, Roadmap):*

- package providers (pacman)
- an AUR / PKGBUILD-from-git source that doesn't need paru to bootstrap
- hooks
- lockfile
- secrets
- systemd units, groups and users
- other platforms
- `pkg_alts` introspection in `mdot specs`

*Research not yet done:* a broader survey of dotfile managers beyond @related, which only covers
tools from the author's own experience and the earlier session's analysis, plus the narrow 3-way
diff search (@prior-art-3way).

#show: appendix

= Translating `~/dotfiles-v2` <translation>

This appendix answers RQ6 on paper. It uses the spec syntax from `design.typ` (Lua API).

*`hyprland.yaml`.* The link plus a package list becomes one owning spec plus package-only specs:

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

*`utils.yaml` / `dev-utils.yaml`.* The long tail of packages with no config is handled with plain
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

*`modules/bash`.* Repo files whose names differ from the target, and several target paths:

```lua
return spec {
  name("bash"),
  config(dirs.home_config["bash"]),
  config(dirs.home[".bashrc"],       { from = "configs/bash/bashrc.sh" }),
  config(dirs.home[".bash_profile"], { from = "configs/bash/bash_profile.sh" }),
}
```

*`modules/krita`.* comtrya uses `walk_dir` into `~/.config`, and krita rewrites its own `kritarc`:

```lua
return spec {
  name("krita"),
  config(dirs.home_config["kritashortcutsrc"]),
  patch(dirs.home_config["kritarc"], { lang = "ini", edits = {
    set(q[[(setting (setting_name) @k (#eq? @k "canvasState") (setting_value) @v)]], "OPENGL_SUCCESS"),
  } }),
}
```

The krita keys are illustrative. Which queries are actually needed is S2. This query worked
unchanged on the real kritarc (@results-s1).

*`Comtrya.yaml` variables.* These become `vars` + `render`:

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

This `render` query does not work on the real `style.css`: it matches `sans-serif`, not the font
(@results-s1, failure 4).

*`modules/kanata`, `tablet.yaml`, `phinger-cursors.yaml`, `paru.yaml`.* These are AUR packages, some
built from a custom git repo (`NexushasTaken/kanata-bin`). Until then, only their configs can be
expressed. Their package source waits for the AUR phase. kanata's uinput group/udev setup needs
system scope (files) and account management (groups, deferred).

*`nexos.yaml`.* Its `depends` list of modules and fonts becomes `enabled(host.name == "nexos")` on
host-specific specs. Package-only specs cover the fonts and misc packages.

*Findings:*

+ Two additions to `config()` came out of this translation:
  - `walk`: link files individually, for `.cargo` and krita
  - `from`: a repo name that differs from the target name, for bash
+ AUR, groups and hooks are the only deferred constructs.
+ Nothing in dotfiles-v2 is silently unrepresentable.

= Translating `~/dotfiles-yolk` <translation-yolk>

The same exercise for the older setup (@yolk-setup). Yolk's constructs map onto mdot like this:

#table(
  columns: (1fr, 1.4fr, auto),
  [Yolk], [mdot], [Status],
  [egg with `targets: "~/.config/btop"`], [`spec { name("btop"), file.link(...) }`], [Phase 1],
  [`targets` map (`"bashrc.sh": "~/.bashrc"`)], [`file.link` with `from`, as in @translation], [Phase 1],
  [`enabled: true/false`], [`enabled(...)`], [Phase 1],
  [`strategy: "merge"` (`home`, `gh`)], [file-level links (`walk`), as for `.cargo` and krita],
  [Phase 1],
  [`data` table + comment markers], [`vars` + `render`], [Phase 4],
  [`data.git.name`, `data.git.email`], [per-spec `config {...}`, given by a host], [Phase 4],
  [`pre_deploy` mkdir, `post_undeploy` rmdir], [parent directories created by the planner;
    removing an emptied directory needs checking against the removal rules], [Phase 1/2],
  [package array in `archlinux.sh`], [one package-only spec each, `package(...)`], [Phase 5],
  [`paru` / `kanata-bin` from git], [AUR / PKGBUILD-from-git source], [Phase 5+],
  [`systemctl --user enable`], [no clause yet (systemd units are future work)], [—],
  [`wget` + `tar` (phinger-cursors)], [`net.download` plus extraction, or the AUR package], [—],
  [`wget` + `chmod +x` (kanata)], [`net.download` plus a file mode, or the AUR package], [—],
  [`git clone` + `./install.sh` (themes)], [no clause; not a file download], [—],
  [uinput group, udev rule, `/etc` unit], [system scope and account management], [3 / deferred],
)

*Findings for `net.download`.* The two real downloads (@yolk-setup) differ in the two ways the open
question in ADR 0023 cares about:

+ The kanata binary is a single file at a pinned version, so a required hash fits it.
+ The phinger-cursors archive is fetched from `latest` and unpacked into a directory. It would need
  either a pinned URL plus a hash, or a package. Extraction is a separate feature from download
  (the unpacked directory is many resources, not one).

Both cases also have a package that does the job, so a download clause is a fallback for software
with no package, not a replacement for the package provider.

*Findings for the rest of the design:*

+ dotfiles-yolk adds no new `config()` option beyond `walk` and `from`.
+ It adds three constructs with no clause yet: enabling a systemd unit, running an installer after
  `git clone`, and extracting an archive.
+ Yolk's per-egg `enabled` flag is the only per-machine switch it had. That is enough for one
  machine, and the reason `enabled(...)` takes a Lua expression in mdot.
