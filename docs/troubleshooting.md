# Troubleshooting

mdot reports every problem it finds in one run, each on its own line starting with `error:`,
`conflict:` or `warning:`. A message about a file starts with its path. Problems in a spec's links
start with the spec's name.

## Conflicts

| Message | Cause | Fix |
|---|---|---|
| `conflict: <dst>: regular file, not managed by mdot` | a file is where the link should go | move it into your repo, or delete it |
| `conflict: <dst>: directory, not managed by mdot` | an existing config directory | move its contents into the spec, then delete it |
| `conflict: <dst>: symlink to <target>, not managed by mdot` | a link you (or another tool) made, pointing somewhere else, or a relative link | delete the link |
| `conflict: <dst>: ..., changed since mdot made it` | mdot made a link here, then it was replaced or retargeted | delete what's there; mdot makes its link again |
| `conflict: <dst>: a parent is not a directory, ...` | a file sits where a parent directory of `dst` should be | move that file |
| `conflict: apply refused; run 'mdot plan' to review` | `apply` won't run with conflicts | fix the conflicts `plan` shows |

See [How mdot manages files](managing-files.md#conflicts).

## Finding the repo and host

| Message | Fix |
|---|---|
| `no repo here: run mdot in a directory with specs/, or pass --repo <dir>` | `cd` to your repo, or use `--repo` |
| `<dir>: not a repo (no specs/)` | `--repo` must point at the directory that contains `specs/` |
| `hosts/<name>.lua does not exist; hosts/ has: ...` | create `hosts/<name>.lua` for this machine, or fix the name in `preview` / `specs --host` |
| `cannot determine the hostname; set one` | the OS reports no hostname; set one (`hostnamectl hostname <name>` on systemd) |
| `unsafe host name "..."` | a hostname cannot be empty, `.`, `..`, or contain `/` or `\` |
| `host "Name" has uppercase; host names are lowercase` | use the lowercase name (and a lowercase file name) |
| `warning: hostname "..." is not a valid hostname (only a-z, 0-9, '-' and '.')` | only a warning; rename the machine to silence it |
| `warning: hosts/<File>.lua: host file names must be lowercase; this file is never used` | rename the file to lowercase |

## In a spec

| Message | Cause |
|---|---|
| `<spec>: src "<src>" does not exist` | typo in `src`, or the file isn't in the spec directory |
| `<spec>: src "<src>" does not exist (symlink target missing: <target>)` | `src` is a symlink in your repo whose target is gone |
| `<spec>: src "<src>" is outside specs/<spec>/` | `src` uses `..` to reach another directory; each spec only uses its own files |
| `<spec>: src "<src>" is outside specs/<spec>/ (resolves to <path>)` | `src` is a symlink that points outside the spec |
| `<spec>: dst "<dst>" contains $; only a leading ~ is expanded` | environment variables aren't expanded; use `~` or `mdot.dirs` |
| `<spec>: dst "<dst>" must start with ~/ or be absolute` | `dst` is a relative path |
| `<dst>: dst of both <a> and <b>` | two links want the same path; remove one |
| `specs/<spec>/spec.lua: declares nothing` | a `spec.lua` must link something or depend on something; delete it to link the whole directory instead |
| `<file>: unknown spec "<name>" in depends; specs/ has: ...` | typo in `depends`, or the spec directory doesn't exist |
| `depends cycle: a -> b -> a` | two specs depend on each other; remove one direction |
| `hosts/<host>.lua: file.link is not allowed in a host file; put it in a spec` | move the link into a spec, and `depends` on that spec |
| `config.lua: must not return a value; it only sets mdot.vars` | remove the `return` from `config.lua` |

## Lua errors

Lua errors carry the file and line:

| Message | Cause |
|---|---|
| `specs/x/spec.lua:3: file.link: expected file.link(src, dst) or file.link { names..., into = dir }` | wrong arguments to `file.link` |
| ``specs/x/spec.lua:3: file.link: the batch form needs `into` `` | `file.link { ... }` without `into` |
| `specs/x/spec.lua:3: file.link: the batch form needs at least one name` | `file.link { into = ... }` with no names |
| `specs/x/spec.lua:3: file.link: name 1 ("config/") has no file name` | a name in `file.link { ... }` ending in `/`, `.` or `..` |
| `specs/x/spec.lua:3: file.link: unknown field <name>` | a misspelled field in `file.link { ... }` (only `into` and `dot` exist) |
| `specs/x/spec.lua:3: depends: argument 2 must be a string` | `depends` takes spec names only |
| `specs/x/spec.lua: entry 2.1: not a clause (got string)` | something in `spec { ... }` that isn't a clause or a list of clauses |
| `specs/x/spec.lua: must return spec { ... }, got nil` | the file forgot `return spec { ... }` |
| `specs/x/spec.lua:5: cannot set string.upper` | libraries are read-only |
| `specs/x/spec.lua:5: cannot set mdot.vars.font` | only `config.lua` and host files may set variables |
| `specs/x/spec.lua:5: unknown field mdot.os.hostnme` | a misspelled field in `mdot`, `mdot.os` or `mdot.dirs` |
| `specs/x/spec.lua:5: attempt to call a nil value (global 'print')` | use `mdot.print`; `print`, `io`, `os` and `require` don't exist in specs |

## Variables

See [Hosts and variables](hosts-and-vars.md#the-rules) for the rules behind these.

| Message | Fix |
|---|---|
| `config.lua: mdot.vars.x: empty {} is not allowed; give a list at least one element` | give the list a default element |
| `config.lua: mdot.vars.x: mixed table: ...` | use either named fields or a list, not both |
| `config.lua: mdot.vars.x: list with gaps: keys must be exactly 1..n` | remove the `nil`s from the list |
| `config.lua: mdot.vars.x: a function cannot be a var; vars hold only data` | put the function in the spec that uses it |
| `<file>: mdot.vars.x: expected number, got string` | a host can't change a variable's type |
| `hosts/h.lua: mdot.vars.x: not in config.lua; a host may only override existing vars` | define it in `config.lua` first |
| `hosts/h.lua: mdot.vars.x: removed; a host may not remove a var` | a host set a field to `nil`; set a value instead |

## State and runs

| Message | Fix |
|---|---|
| `another mdot run is using <dir>; try again when it finishes` | wait for the other `mdot apply` to finish |
| `warning: state is from repo <old>, this is <new>` + `continue anyway? [y/N]` | you're in a different repo than last time; see [One repo per user](managing-files.md#one-repo-per-user) |
| `cannot ask for confirmation: stdin is not a terminal; use --yes` | in scripts, run `mdot apply --yes` |
| `cannot ask to continue: stdin is not a terminal` | run once from a terminal to answer the repo question |
| `.../state.json: version N is newer than this mdot knows (1); upgrade mdot` | the state was written by a newer mdot |
| `.../state.json: not valid JSON: ...` (or another `state.json` error) | the state file is damaged; delete it. The next `plan` shows your existing links as `(already linked; record only)`, and `apply` records them again. |
| `<dst>: could not create link: permission denied` (during `apply`) | `apply` stopped here; fix the permissions and run `apply` again, it continues where it stopped |
| `warning: <dir>: not removed, it is not empty` | a directory mdot created now holds other files; mdot leaves it alone |

## Seeing more

- `mdot plan -v` also lists links that are already right.
- `mdot plan -v=2` shows, for every link, the desired `src`, the recorded `src` and what is on
  disk.
- `mdot specs` shows why a spec is (or isn't) used.
- `mdot.print(...)` in a spec prints values while it loads.
