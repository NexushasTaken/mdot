# Writing specs

A `spec.lua` returns `spec { ... }`, a list of *clauses*:

```lua
return spec {
  file.link("bashrc", "~/.bashrc"),
  file.link("bash_profile", "~/.bash_profile"),
  depends("starship"),
}
```

A clause is a description, not an action. `file.link(...)` doesn't create anything when the file
runs; it returns a value saying "this link should exist". mdot collects them and decides what to
do. That's why `mdot plan` is always safe to run.

## `file.link(src, dst)`

Makes `dst` a symlink to `src`.

```lua
file.link("config", "~/.config/hypr")      -- a directory
file.link("bashrc", "~/.bashrc")           -- a file, renamed
file.link("gitconfig", mdot.dirs.config .. "/git/config")
```

- **`src`** is relative to the spec's directory. It must exist, and it must stay inside the spec
  directory.
- **`dst`** is where the link goes. A leading `~` means your home directory. Otherwise it must be
  an absolute path.
- **No `$`.** `"$XDG_CONFIG_HOME/foo"` is an error, not an expansion. Use `mdot.dirs` for
  standard directories (see [The `mdot` table](lua-api.md)).
- Paths are cleaned up: `~/a//b/../c` is `~/a/c`.
- Missing parent directories of `dst` are created, and mdot removes them again when it removes the
  last link inside them.

Two links with the same `dst`, in one spec or in two, are an error.

## `file.link { names..., into = dir }`

Links several files into one directory, each under its own name:

```lua
-- ~/.config/systemd/user/i3-session.service -> i3-session.service, ...
file.link {
  "i3-session.service", "i3-session.target", "kanata.service",
  into = "~/.config/systemd/user",
}
```

With `dot = true`, each target name gets a leading dot:

```lua
-- ~/.Xresources -> Xresources, ~/.xinitrc -> xinitrc
file.link { "Xresources", "xinitrc", into = "~", dot = true }
```

A name can be a path inside the spec; the target uses only its last part, and the whole name stays
the source:

```lua
-- ~/.bashrc.sh -> config/bashrc.sh, ~/.bash_profile.sh -> config/bash_profile.sh
file.link { "config/bashrc.sh", "config/bash_profile.sh", into = "~", dot = true }
```

To give a file a different name (`config/bashrc.sh` to `~/.bashrc`), use `file.link(src, dst)`.

`into` follows the same rules as `dst`. The list needs at least one name. Any other field, a name
that isn't a string, or a name with no file name at the end (`config/`, `.`, `..`) is an error.

## `depends(names...)`

Pulls in other specs:

```lua
-- specs/desktop/spec.lua
return spec {
  depends("hypr", "waybar", "dunst"),
}
```

- Names are looked up in `specs/` at the repo root, wherever the calling file is.
- A spec reached more than once is deployed once.
- An unknown name is an error that lists the specs that exist.
- A cycle (`a` depends on `b`, `b` depends on `a`) is an error that names it.

A spec that only has `depends` works as a **group**: `desktop` above links nothing itself, it just
bundles other specs.

## Helper functions

`spec.lua` is ordinary Lua, so you can write functions. An entry in `spec { ... }` may be a list of
clauses, which mdot flattens in order:

```lua
local function user_units(...)
  local out = {}
  for _, name in ipairs({ ... }) do
    out[#out + 1] = file.link(name, "~/.config/systemd/user/" .. name)
  end
  return out
end

return spec {
  user_units("kanata.service", "mako.service"),
  file.link("environment.d", "~/.config/environment.d"),
}
```

Anything else in the list (a string, a number, a table that isn't a clause or a list of clauses) is
an error that names its position, such as `entry 2.1`.

Helpers live in the file that uses them: there is no `require`, so files cannot share code. See
[The `mdot` table](lua-api.md#what-lua-can-do-in-a-spec).

## Choosing per machine

Use `mdot.os` to pick a target per OS:

```lua
local dst
if mdot.os.name == "macos" then
  dst = "~/Library/Application Support/lazygit"
else
  dst = "~/.config/lazygit"
end

return spec {
  file.link("config.yml", dst .. "/config.yml"),
}
```

Use `mdot.vars` for values that differ per machine (see [Hosts and variables](hosts-and-vars.md)).
To include a spec on only some machines, list it in only those host files instead of branching
inside it.

## Seeing what a spec does

- `mdot plan` shows every link with its spec.
- `mdot.print(...)` prints from a spec while it loads:
  `mdot.print("dst is", dst)` → `specs/lazygit/spec.lua:7: dst is	~/.config/lazygit`.
- `mdot specs <name>` shows what a spec depends on and what needs it.
