#import "../template.typ": adr

#adr(number: 22, title: [`link` has a batch form: `link { names..., into = dir, dot? }`], status: [Accepted], date: [2026-10-11])[
= Context
ADR 0015 made `link(src, dst)` the only deployment clause. In real specs most links repeat their
name in `dst`: `x11` links four files as `Xresources` to `~/.Xresources`, and `systemd-user` links
three units into one directory. The repetition is in `dst`, not in the call. Renames such as
`config/bashrc.sh` to `~/.bashrc` still need an explicit `dst`.

= Options
- A helper function in each `spec.lua`. It works today (ADR 0018 flattens lists), but every spec
  repeats it and `require` is limited to the repo.
- `into` only. It fits `systemd-user` but not `x11`, which needs a leading `.`.
- `into` plus a boolean `dot`. Chosen.
- `dot` as a string prefix. More general than any real case, and the name would be misleading. It can
  be added later as `prefix` without breaking anything.

= Decision
`link` has two forms, told apart by its arguments:

#table(
  columns: (auto, 1fr),
  [Call], [Meaning],
  [`link(src, dst)`], [Two strings. One link; `dst` is chosen by the author, so this is the form for
    renames.],
  [`link { names..., into = dir }`], [One table. Each name in the list is a `src`, and its `dst` is
    `dir/<name>`.],
  [`link { names..., into = dir, dot = true }`], [The same, with `.` prepended to each name:
    `dir/.<name>`.],
)

- `into` is required in the table form. It is expanded like `dst` (ADR 0020): a leading `~` becomes
  `$HOME`, and a `$` is a load error.
- `dot` is optional, a boolean, and defaults to `false`.
- The list needs at least one name, and every entry is a string. A single name is valid
  (`link { "xinitrc", into = "~", dot = true }`).
- A name is a path relative to the spec directory (ADR 0015). Its `dst` uses the last path component
  only, so `link { "config/bashrc.sh", into = "~" }` links `~/bashrc.sh`.
- Any other call is an error that names the clause position (ADR 0018): wrong argument count or
  types, a table without `into`, an empty list, a non-boolean `dot`, or an unknown key. An unknown key
  is an error so that a typo such as `intoo` cannot silently link nothing.
- The batch form is sugar. It produces the same links as the equivalent `link(src, dst)` calls, so
  conflicts (ADR 0016), same-`dst` errors (ADR 0021) and missing-`src` errors apply to each link
  unchanged.

= Consequences
- Extends ADR 0015; its `link(src, dst)` form is unchanged.
- `x11` becomes one clause and `systemd-user` becomes one clause. `bash` stays as it is.
- The loader should turn both forms into the same internal link value, so the planner never sees the
  difference.
- Open: whether a name should be able to carry its own `dst` inside the batch form. For now, use a
  separate `link(src, dst)` call.
]
