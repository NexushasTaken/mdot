# The `mdot` table

Everything mdot gives your Lua files lives in one global table, `mdot`. For a shorter name, use a
local: `local v = mdot.vars`.

| Member | What it is |
|---|---|
| [`mdot.os`](#mdotos) | facts about this machine |
| [`mdot.dirs`](#mdotdirs) | this machine's standard directories |
| [`mdot.vars`](#mdotvars) | your variables (see [Hosts and variables](hosts-and-vars.md)) |
| [`mdot.print`](#mdotprint) | print from a spec while it loads |

Reading any other member (`mdot.g`) is an error. All of `mdot` is read-only, except that
`config.lua` and host files may write into `mdot.vars`.

## `mdot.os`

| Field | Value | Example |
|---|---|---|
| `name` | the OS | `"linux"`, `"macos"`, `"windows"`, `"android"` |
| `family` | the OS family | `"unix"`, `"windows"` |
| `arch` | the CPU architecture | `"x86_64"`, `"aarch64"` |
| `bitness` | a number | `64` |
| `distribution` | Linux: the distro's `ID` from `/etc/os-release`; `nil` elsewhere | `"arch"`, `"debian"` |
| `version` | the OS version, or `nil` if the OS reports none | `"14.5"`; `nil` on Arch |
| `codename` | the release codename, or `nil` | `"bookworm"`; `nil` on Arch |
| `edition` | the edition/variant, or `nil` | `"workstation"` on Fedora |
| `hostname` | the name that picked the host file | `"laptop"` |

Fields that don't apply are `nil`, so `if mdot.os.distribution == "arch"` is safe everywhere. A
misspelled field (`mdot.os.hostnme`) is an error, not a silent `nil`.

Under `mdot preview <host>`, `hostname` is `<host>`, but every other field still describes the
machine you run it on.

## `mdot.dirs`

This machine's standard directories, as absolute paths without a trailing slash. A directory that
doesn't exist on this OS is `nil`.

| Name | Linux | macOS | Windows |
|---|---|---|---|
| `home` | `~` | `~` | `C:\Users\you` |
| `config` | `$XDG_CONFIG_HOME` or `~/.config` | `~/Library/Application Support` | `AppData\Roaming` |
| `config_local` | same as `config` | `~/Library/Application Support` | `AppData\Local` |
| `data` | `$XDG_DATA_HOME` or `~/.local/share` | `~/Library/Application Support` | `AppData\Roaming` |
| `data_local` | same as `data` | `~/Library/Application Support` | `AppData\Local` |
| `cache` | `$XDG_CACHE_HOME` or `~/.cache` | `~/Library/Caches` | `AppData\Local` |
| `state` | `$XDG_STATE_HOME` or `~/.local/state` | `nil` | `nil` |
| `executable` | `$XDG_BIN_HOME` or `~/.local/bin` | `nil` | `nil` |
| `runtime` | `$XDG_RUNTIME_DIR` | `nil` | `nil` |
| `preference` | same as `config` | `~/Library/Preferences` | `AppData\Roaming` |
| `font` | `~/.local/share/fonts` | `~/Library/Fonts` | `nil` |
| `audio`, `desktop`, `document`, `download`, `picture`, `public`, `template`, `video` | your XDG user dirs (`~/Music`, ...) | `~/Music`, `~/Desktop`, ...; `template` is `nil` | `Music`, `Desktop`, ... |

```lua
file.link("config", mdot.dirs.config .. "/nvim")
local bin = mdot.dirs.executable or (mdot.dirs.home .. "/bin")
```

A spec without `spec.lua` always links to `~/.config/<name>`, whatever `mdot.dirs.config` says.

## `mdot.vars`

Your variables. `config.lua` defines them, a host file may change them, specs only read them. See
[Hosts and variables](hosts-and-vars.md).

## `mdot.print`

```lua
mdot.print("cursor:", mdot.vars.cursor.name, 24)
```

```
specs/hypr/spec.lua:3: cursor:	phinger-cursor-dark	24
```

Each value goes through `tostring`, the values are joined with tabs, and the line starts with the
file and line number. Output goes to stdout immediately, so it appears before the plan (or before
the `apply?` question). It works in specs, host files and `config.lua`.

Plain `print` does not exist; use `mdot.print`.

## What Lua can do in a spec

Spec files, host files and `config.lua` run in a restricted Lua 5.4. Loading a file must not change
anything on your system, which is what makes `mdot plan` safe.

**Available:**

- `string`, `table`, `math`, `utf8`;
- `pairs`, `ipairs`, `next`, `select`, `type`, `tostring`, `tonumber`, `error`, `assert`, `pcall`,
  `setmetatable`, `getmetatable`;
- `spec`, `file.link`, `depends` and `mdot`.

**Not available:** `print`, `io`, `os`, `require`, `load`, `dofile`, `loadfile`, `debug`,
`coroutine`, `package`, `string.dump`, `rawset`, `rawget`. Reading files or environment variables
is not possible, by design.

**Each file is separate.** Every file runs in its own fresh environment. A global you set in one
file is not visible in another, and there's no `require`, so a helper function lives in the file
that uses it.

**The libraries are read-only.** `string.upper = nil` is an error:

```
error: specs/a/spec.lua:1: cannot set string.upper
```

A side effect of this: `next(string)` is `nil` and `#math` is `0`, but `pairs(string)` works
normally.
