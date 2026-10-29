# How mdot manages files

## What mdot looks at

For every link, mdot compares three things:

- **desired**: what your specs ask for now;
- **recorded**: what mdot made last time (from its state file);
- **live**: what is actually at that path on disk.

From those three, it decides what to do:

| Situation | What `plan` shows |
|---|---|
| wanted, nothing there yet | `+` create |
| wanted, already linked exactly right, but mdot didn't make it | `~` `(already linked; record only)`: mdot starts tracking it |
| wanted, something else is there | `!` conflict: `not managed by mdot` |
| wanted, mdot made it, unchanged | nothing (`=` with `-v`) |
| wanted, the spec now points it elsewhere, disk still has mdot's old link | `~` update |
| wanted, mdot made it, someone deleted it | `+` `(removed by hand)` |
| wanted, mdot made it, someone changed it | `!` conflict: `changed since mdot made it` |
| not wanted any more, still as mdot left it | `-` remove |
| not wanted any more, already deleted | `-` `(already gone)`: mdot only forgets it |
| not wanted any more, but someone changed it | `!` conflict: `changed since mdot made it` |

## What mdot owns

mdot owns **the link itself**: whether it exists and where it points. It does not track what's
inside the files. Because they are symlinks, editing `~/.bashrc` edits the file in your repo. That
is a change to your repo, not something mdot reports. Use git to see and keep those changes.

mdot links with **absolute paths**. A link that points to the right file through a relative path
(`../dotfiles/specs/bash/bashrc`) does not count as "exactly right"; it is a conflict.

## Conflicts

A conflict means mdot found something at a path that it would have to overwrite or delete, and it
didn't make that thing (or it changed since). mdot never resolves this for you, and there is no
`--force`.

```
nvim
  ! link  ~/.config/nvim -> config
conflict: ~/.config/nvim: directory, not managed by mdot
```

The `conflict:` line says what is there:

- `regular file`, `directory`, `special file` (a socket, pipe or device), or `symlink to <target>`;
- `a parent is not a directory`: a file sits where a parent directory should be;

and whose it is:

- `not managed by mdot`: mdot never made it. Typically an existing config you haven't moved into
  the repo yet.
- `changed since mdot made it`: mdot made a link here, and it was replaced or retargeted since.

To fix it, deal with the path yourself: move the file into your repo, back it up, or delete it.
Then run `mdot plan` again. `apply` won't run until no conflicts are left, so it never stops
halfway because of one.

## Removing things

To stop managing something, remove it from your specs: delete the `file.link`, remove the spec
from `depends`, or delete the spec directory. The next plan shows its links as removals, and
`apply` deletes them.

A removal only deletes the **symlink**. Your files stay in the repo. If the link was changed since
mdot made it, the removal is a conflict instead, so mdot never deletes something it didn't make.

To keep a link but stop managing it, there's no special command: delete the link yourself, then
remove it from your specs.

## Directories mdot creates

If a link's parent directory doesn't exist, mdot creates it (`~/.config/systemd/user/` for a unit
file) and remembers that it did. When the last link inside such a directory is removed, mdot
removes the directory too, deepest first.

mdot only removes directories it created, and only when they're empty. If something else put a
file in one, mdot leaves it, prints a warning, and stops tracking it:

```
warning: /home/you/.config/foo: not removed, it is not empty
```

## The state file

mdot keeps its record of what it made in one directory per user:

| OS | Location |
|---|---|
| Linux, macOS | `$XDG_STATE_HOME/mdot-data`, or `~/.local/state/mdot-data` |
| Windows | `AppData\Local\mdot-data` (or `$XDG_STATE_HOME\mdot-data` if set) |

`XDG_STATE_HOME` is used only when it is an absolute path.

It holds:

- `state.json`: the repo path, every link mdot made, and the directories it created;
- `lock`: keeps two mdot runs from changing things at the same time.

Only `apply` writes state. `plan` reads it and never creates the directory. State is saved after
every step, so if `apply` is interrupted, the next `plan` picks up where it left off: links already
made show as done, and a link made just before the interruption is recognised and tracked.

Don't edit `state.json` by hand. If it is broken beyond repair, delete it. Every link mdot made will
then show as `(already linked; record only)` on the next plan, and `apply` records them again.

**Trying another repo without touching your setup:** point `XDG_STATE_HOME` somewhere else for
that shell, and use a test home if you don't want real links:

```sh
XDG_STATE_HOME=/tmp/mdot-test HOME=/tmp/fake-home mdot plan
```

## One repo per user

mdot remembers the repo path it last applied. If you run it from a different repo, it warns and
asks first:

```
warning: state is from repo /home/you/dotfiles, this is /home/you/dotfiles-new
continue anyway? [y/N]
```

Answering yes plans against the old records, and a successful `apply` then remembers the new
path. `--yes` does not answer this question, and without a terminal mdot refuses.

If you moved or renamed the repo, answer yes: the old links still point to the old location, so
`plan` shows each one as an update (`~`) to the new path, and `apply` repoints them.

## Two runs at once

`plan` runs alongside other `plan`s. `apply` needs mdot to itself:

```
error: another mdot run is using /home/you/.local/state/mdot-data; try again when it finishes
```

The lock is released when the other run exits, even if it crashed.
