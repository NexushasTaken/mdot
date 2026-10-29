#import "../template.typ": adr

#adr(number: 77, title: [The state directory is `<base>/mdot-data` on every OS; `XDG_STATE_HOME` is read everywhere], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0062 put all state in one directory, `$XDG_STATE_HOME/mdot/`, and ADR 0063 put the lock file
in it. Both left open which directory macOS and Windows use. `XDG_STATE_HOME` is a Linux (XDG)
convention, and ADR 0062's way to try another repo without touching the real setup (point
`XDG_STATE_HOME` elsewhere) worked only where mdot reads it.

Facts that shaped it:
- The `dirs` crate's `state_dir()` returns nothing on macOS and Windows (ADR 0043).
  `data_local_dir()` is `~/Library/Application Support` on macOS and `AppData\Local` on Windows.
- Neovim (`:help base-directories`, checked 2026-10-29): `stdpath("state")` is
  `$XDG_STATE_HOME/nvim` or `~/.local/state/nvim` on Unix, macOS included, and
  `~/AppData/Local/nvim-data` on Windows. The `XDG_*` variables are used on every OS if defined.
  The `-data` suffix keeps Neovim's data apart from its Windows config dir, `~/AppData/Local/nvim`.
- The XDG Base Directory Specification: an empty variable means the default is used; a relative path
  is invalid and should be ignored.

= Options
- *macOS:* `data_local_dir()/mdot-data` (`~/Library/Application Support/mdot-data`), or
  `~/.local/state/mdot-data` as in Neovim. The second was chosen.
- *`XDG_STATE_HOME`:* read on every OS, or only on Linux. Every OS was chosen.
- *Name:* `mdot` or `mdot-data`. `mdot-data` was chosen.

= Decision
From the author:
- *Windows: `data_local_dir()/mdot-data`* (`AppData\Local\mdot-data`), similar to how Neovim stores
  its state.
- *macOS: `~/.local/state/mdot-data`,* as Neovim does.
- *The name is `mdot-data`:* it is mdot's data. A plain `mdot` implicitly says the directory can be
  edited by hand; `-data` says it is not to be edited by hand.

Claude's recommendations, accepted by the author (reasons are Claude's):
- *`XDG_STATE_HOME` is read on every OS.* ADR 0062's testing trick then works everywhere; it is one
  rule with no OS exception; Neovim does the same.
- *Linux also uses `mdot-data`.* The author's reason for the name does not depend on the OS. This
  changes ADR 0062's `$XDG_STATE_HOME/mdot/`.

```
base = XDG_STATE_HOME if set
       else ~/.local/state     (Linux, macOS)
       else data_local_dir()   (Windows: AppData\Local)
state dir = base/mdot-data
lock      = state dir/lock
```

#table(
  columns: 2,
  [*OS*], [*Default state directory*],
  [Linux], [`~/.local/state/mdot-data`],
  [macOS], [`~/.local/state/mdot-data`],
  [Windows], [`AppData\Local\mdot-data`],
)

Accepted additions:
+ *An empty or relative `XDG_STATE_HOME` counts as unset;* the default is used, as the XDG
  specification says.
+ *If the base cannot be found* (no home directory, no `AppData\Local`), it is an error, exit 2
  (ADR 0053), naming what is missing. mdot does not guess another place.
+ *ADR 0062 and 0063 stay Accepted;* only the path changes. The lock is still `<state dir>/lock`.
+ *`design.typ`* defines `<state dir>` once with the pseudocode above, and the state tree, the repo
  path and the locking text use it. The open item on macOS and Windows is removed.

= Consequences
- Closes the open item on macOS and Windows in ADR 0062 and ADR 0063.
- Linux and macOS share one rule; only Windows' default differs.
- To try another repo without touching the real setup, point `XDG_STATE_HOME` elsewhere, on any OS.
]
