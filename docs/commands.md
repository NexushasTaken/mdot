# Commands

```
mdot [--repo <dir>] [-v[=<level>]] [--color <when>] <command>
```

| Command | What it does |
|---|---|
| [`mdot plan`](#mdot-plan) | show what `apply` would do; changes nothing |
| [`mdot apply [--yes]`](#mdot-apply) | do it |
| [`mdot up [--yes]`](#mdot-up) | `plan` and `apply` in one go: show the plan, ask, do it |
| [`mdot preview <host>`](#mdot-preview-host) | show what another machine would get |
| [`mdot specs [<name>] [--host <host>]`](#mdot-specs) | show which specs are used and why |

## Global flags

| Flag | Meaning |
|---|---|
| `--repo <dir>` | the repo root. Default: the current directory, if it has `specs/`. |
| `-v`, `--verbose` | also show resources with nothing to do (`=` lines). |
| `-v=2`, `--verbose=2` | also show, for each resource, what is desired, what mdot recorded, and what is on disk. The level is attached with `=`: `-v 2` is not level 2. |
| `--color <when>` | `auto` (default), `always` or `never`. Only the `error:`, `conflict:` and `warning:` words are colored. `auto` colors when stderr is a terminal and `NO_COLOR` is unset or empty; `--color=always` wins over `NO_COLOR`. |
| `--help`, `--version` | |

## `mdot plan`

Loads the repo, compares it with what mdot deployed last time and with what is on disk, and prints
what `apply` would do. It never changes a file.

```
bash
  + link  ~/.bashrc -> bashrc  (removed by hand)
nvim
  ! link  ~/.config/nvim -> config
conflict: ~/.config/nvim: symlink to /tmp/other, changed since mdot made it
git
  - link  ~/.config/git  (spec removed)

Plan: 1 to create, 1 to delete, 1 conflict.
```

Resources are grouped under their spec, in dependency order (a spec comes after the specs it
depends on). Each line is `symbol kind dst -> src`, with paths as you wrote them.

| Symbol | Meaning |
|---|---|
| `+` | create the link |
| `~` | update it (the spec now points it somewhere else) |
| `-` | remove it |
| `=` | already right (only with `-v`) |
| `!` | conflict: mdot won't touch it, see the `conflict:` line under it |

A detail in parentheses says why:

| Detail | Meaning |
|---|---|
| `(removed by hand)` | mdot made this link, someone deleted it; it will be made again |
| `(already linked; record only)` | the link is already exactly right; mdot only starts tracking it |
| `(spec removed)` | the spec is no longer reached from this host |
| `(clause removed)` | the spec still exists but no longer has this link |
| `(already gone)` | not wanted any more and already deleted; mdot only forgets it |

The last line counts the changes, or says `No changes.` when there is nothing to do.

**Exit code:** 0, even when there are changes; 1 if there is a conflict; 2 on an error.

## `mdot apply`

Plans, asks once, then makes the changes.

```
$ mdot apply
apply? [y/N] y
bash
  + link  ~/.bashrc -> bashrc

Applied: 1 created.
```

- With a conflict, `apply` refuses before asking:
  `conflict: apply refused; run 'mdot plan' to review`. Fix the conflicts and run it again.
- With nothing to do it prints `No changes.` and doesn't ask.
- The question accepts `y` or `yes` (any case); anything else, including just Enter, is no.
- `--yes` skips the question. Without a terminal (in a script), `--yes` is required.
- Removals run first, then updates, then new links. Each line is printed as soon as its step is
  done.
- If a step fails (for example, permission denied), `apply` stops there and prints the error under
  that line. Everything before it is done and recorded; run `mdot plan` to see what's left.

**Exit code:** 0 on success or when you answer no; 1 if refused (conflicts, no terminal); 2 if a
step failed or the repo could not be loaded.

## `mdot up`

The same as `mdot plan && mdot apply`, in one run: it shows the plan, asks once, then makes those
exact changes. Nothing can change between what you read and what is applied, because the plan is
computed once and mdot holds its lock the whole time.

```
$ mdot up
bash
  + link  ~/.bashrc -> bashrc

Plan: 1 to create.
apply? [y/N] y
bash
  + link  ~/.bashrc -> bashrc

Applied: 1 created.
```

- Each change shows twice: once in the plan, once when it is done.
- With a conflict, the plan shows it and `up` stops without asking. There is no extra
  "refused" line.
- With nothing to do it prints `No changes.` and doesn't ask.
- `--yes`, the question and running without a terminal work as for `apply`, but the plan is always
  printed first.

**Exit code:** as for `apply`.

## `mdot preview <host>`

Shows what `hosts/<host>.lua` would get on a fresh machine, in `plan`'s format. Every resource
shows as new.

```
$ mdot preview phone
termux
  + link  ~/.termux/termux.properties -> termux.properties
bash
  + link  ~/.bashrc -> bashrc

Plan: 2 to create.
```

`preview` only reads the repo: not your home directory, not mdot's state. Use it to check another
machine's host file from this one.

Lua sees `mdot.os.hostname` as `<host>`. Every other `mdot.os` field, `mdot.dirs` and `~` are still
this machine's. A host file that selects different specs previews accurately; a spec that branches
on `mdot.os.name` shows this machine's branch.

## `mdot specs`

Shows the specs this machine reaches, in dependency order, with what each one depends on and what
needs it, then the specs nothing reaches.

```
$ mdot specs
hypr
  needed by:  desktop
waybar
  needed by:  desktop
desktop
  depends on: hypr, waybar
  needed by:  laptop (host)
bash
  needed by:  laptop (host)
not reached: rofi
```

- `mdot specs <name>` shows only that spec, or `not reached: <name>`.
- `--host <host>` shows another machine's host file instead.
- On a load error, the error comes first, then whatever did load. A `depends` name that doesn't
  exist shows as `<name> (missing)`.

`specs` doesn't read mdot's state and can run while an `apply` is running.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success, including a plan with pending changes, or warnings |
| 1 | mdot refused because of a rule: a conflict, a broken spec rule (a `src` outside its spec, two links with one `dst`, a `depends` cycle, a bad variable), another mdot run holding the lock, or a question it couldn't ask |
| 2 | an error: bad usage, a file that can't be read, a Lua error, a missing spec, host or `src`, a bad hostname, or a failed write during `apply` |

When both 1 and 2 apply, the code is 2.

## Output streams

The plan and `mdot.print` lines go to **stdout**. `error:`, `conflict:` and `warning:` lines go to
**stderr**, so `mdot plan > plan.txt` still shows problems on the terminal.
