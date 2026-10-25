#import "../template.typ": adr

#adr(number: 37, title: [Several templating engines; Yolk-style markers first, with a git clean filter], status: [Accepted], date: [2026-10-25])[
= Context
ADR 0008 chose tree-sitter structural editing (`render`, `patch`) "instead of templating". Experiments
S1/S2 (`research.typ`) showed that this engine is hard to use and not yet safe: the author's real
kritarc and `config.jsonc` already contain parse errors, `ensure` can silently duplicate keys, and no
query could be written without first dumping the parse tree. The author finds tree-sitter too
complicated to be the only way to template a file.

The real need is small. The author's previous setup (Yolk, `research.typ`) had five files in four
eggs (`git`, `alacritty`, `hypr`, `uwsm`) with comment markers that place one value each: git name and
email, font, cursor size. The waybar font is a sixth case.

Yolk-style markers sit in a comment, so the file stays valid for the app:

```
export XCURSOR_SIZE=16   # {< replace_number(vars.cursor.size) >}
```

Editing a repo file in place means each host writes its own value into the git working tree.
Without countermeasures, the repo flip-flops between hosts' values ("git churn").

= Options
- *How a user picks an engine:* a separate clause per engine, one clause with an `engine =` option,
  or the file extension (`style.css.tmpl`).
- *Where markers are evaluated:* in place in the repo file, which the existing `link` keeps
  pointing at (Mode A), or rendered into a regular-file copy at `dst` (Mode B).
- *Git churn:* build a git clean filter in v1, accept churn for now, or design the filter now and
  build it later.
- *What git stores for a marker's value (the canonical value):* a fixed placeholder (a fresh clone
  gets an unusable config), the markers evaluated with the base `vars` (a working default config),
  or the value already in `HEAD` (the stored value could never be changed on purpose).

= Decision
From the author:

- *mdot has several templating engines, and the user picks one per file.* `render` and `patch`
  are the tree-sitter engines (ADR 0008). Each engine is *its own clause*.
- Planned engines besides tree-sitter, not designed: Yolk-style markers, whole-file templates
  (the repo file holds placeholders and mdot renders a copy), content built in Lua by the spec,
  and line/regex patching of app-owned files.
- *The first engine is Yolk-style markers,* with Yolk's syntax: `{< ... >}` acts on its own line,
  `{# ... #}` on the next line. The expression inside a marker is *Lua*.
- *Mode A first:* mdot evaluates the markers with this host's values and rewrites the values in
  the repo file itself. The `link` clause keeps pointing at that file, so the app reads the host's
  value through the link. ADR 0031 (links do not track content) means the link clause is not
  affected. *Mode B* (render to a copy) comes later.
- *Git churn must be fixed,* with a *git clean filter*. Git runs the filter whenever it reads a
  filtered file from the working tree (`add`, `diff`, `status` after a stat change). The filter
  rewrites every marker's value to its canonical value, so git stores the canonical value while
  the working tree keeps the host's value. The filter is designed now and built later.
- *The filter can be turned off for a file.* mdot then edits the file and git sees the real
  values. The author's reason: it has uses, though no concrete example exists yet.
- *The canonical value is the marker evaluated with the base `vars`.* The author's reason: the
  dotfiles are originally the author's, so the committed baseline is the author's value (for
  example cursor size 16). Other hosts and other users override it locally.
- Per-host values (base `vars` plus a host override) are a separate decision.

Accepted additions proposed by Claude:

- *Strictness:* a marker whose replace function finds nothing to replace on its line is an error,
  and nothing is written. This follows the zero-match rule of ADR 0008.
- *The clean step is pure:* it only evaluates markers with the base `vars` inside the ADR 0013
  sandbox. No network, no apply, no prompts. Git runs it on every `add`, `diff` and `status`, so it
  must be fast and give the same output for the same input.

= Open
- The marker clause's name, and which replace functions exist (Yolk has `replace_number` and
  `replace_quoted`, among others).
- The filter on/off option: its default, and whether it is set per clause, globally, or both.
- How the filter gets registered. `.gitattributes` is committed, but the filter's command lives in
  `.git/config`, which is not cloned. Git silently skips an unregistered filter, so on a fresh
  clone host values can be committed until mdot registers it (checked in a scratch repo).
- How marker edits fit the resource model: ADR 0009 requires a desired × recorded × live table per
  kind before it is built.
- What "base `vars`" means once per-host values exist. Until then it is the `vars` returned by
  `config.lua`, which `design.typ` lists as not designed yet.
- Whether markers are found anywhere on a line or only inside the format's comment syntax.
- Whether git's per-file filter command or its long-running `filter.<driver>.process` mode is
  used.
- Mode B and the other planned engines.

= Consequences
- Partly amends ADR 0008: templating is no longer rejected. Tree-sitter stays as one engine
  among several. ADR 0008 itself is unchanged.
- On a fresh clone the repo file holds the canonical values until `apply` runs the markers. The
  canonical values form a working config, so the app still starts.
- `git status` can report a filtered file as modified when a value's length changed, while
  `git diff` is empty. `git add` clears it. Observed in a scratch repo; it looks like git skips the
  content check when the file size differs, which is not verified against git's source.
- mdot writes into the repo working tree, which touches RQ4 (rollback with symlinks into the live
  working tree).
- Formats without comments (plain JSON) cannot carry markers.
]
