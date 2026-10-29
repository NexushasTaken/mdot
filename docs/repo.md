# The repo

```
dotfiles/
  config.lua              -- optional: shared variables (see Hosts and variables)
  hosts/
    <hostname>.lua        -- one per machine: which specs it uses
  specs/
    <name>/               -- one directory per spec
      spec.lua            -- optional: where the files go
      ...                 -- the config files, in any layout
```

mdot finds the repo like this:

1. `--repo <dir>` if you pass it;
2. otherwise the current directory, if it has a `specs/` directory;
3. otherwise it stops with an error.

The repo doesn't have to be a git repository, but it should be: mdot links your files instead of
copying them, so git is where their history lives.

## Specs

A **spec** is a directory in `specs/`. Its name is the directory name. `specs/` is flat: a spec
cannot contain other specs.

A spec is deployed only when the machine's host file reaches it through `depends` (see
[Hosts and variables](hosts-and-vars.md)). Having a directory in `specs/` does nothing by itself.

There are two kinds of spec, decided only by whether `spec.lua` exists.

### Without `spec.lua`

The whole directory is linked to `~/.config/<name>`:

```
specs/
  gdb/
    gdbinit         -- ~/.config/gdb -> specs/gdb
```

Use this for any program whose config lives entirely in `~/.config/<name>`. Such a spec cannot use
`depends` (it has no Lua).

### With `spec.lua`

`spec.lua` decides everything, and **nothing is linked unless it says so**:

```
specs/
  hypr/
    spec.lua
    config/
      hyprland.conf
```

```lua
-- specs/hypr/spec.lua
return spec {
  file.link("config", "~/.config/hypr"),
}
```

Use this when:

- the target isn't `~/.config/<name>` (`~/.bashrc`, `~/.local/share/...`);
- you want to link single files instead of a whole directory (for example when the target
  directory also holds files other programs write);
- the spec needs other specs (`depends`).

A `spec.lua` must declare at least one link or dependency.

**Keep `spec.lua` out of your targets.** If you link the spec directory itself
(`file.link(".", "~/.config/hypr")`), `spec.lua` gets linked into `~/.config/hypr` along with
everything else. Put the files in a subdirectory (`config/`) and link that instead.

**Adding a `spec.lua` turns off the automatic link.** If `specs/nvim/` had no `spec.lua` and you
add one, `~/.config/nvim` is no longer linked unless the new `spec.lua` links it. `mdot plan` will
show it as a removal, so this never happens silently.

### Specs only use their own files

A link's `src` must be inside its own spec directory. `file.link("../other/file", ...)` is an
error, and so is a symlink inside the spec that points outside it. If two specs need the same
file, each keeps its own copy.

## Hosts

`hosts/` holds one Lua file per machine, named after its hostname. See
[Hosts and variables](hosts-and-vars.md).
