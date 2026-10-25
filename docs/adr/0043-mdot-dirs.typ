#import "../template.typ": adr

#adr(number: 43, title: [`mdot.dirs` holds the common dirs; implicit specs keep `~/.config`], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0038 named `mdot.dirs` (XDG or Windows known folders) as a member of `mdot` and left it
undesigned. ADR 0020 expands only a leading `~` in `dst`, makes `$` a load error, hardcodes
`~/.config/<name>` for implicit specs, and suggests a named context value such as `xdg.config` if
other dirs are needed later. ADR 0013 makes loading pure and drops `env()`. Cross-platform is a goal
of mdot, and `design.typ`'s first principle is that mdot ships no database of where software keeps
its config.

The `dirs` crate (already a dependency) resolves the common dirs per OS. Its documentation (checked
in version 5.0.1) gives, for example, `config_dir()` as `$XDG_CONFIG_HOME` or `~/.config` on Linux,
`~/Library/Application Support` on macOS, and `AppData\Roaming` on Windows. Programs do not agree
with it: on macOS Neovim, git and Alacritty use `~/.config`, and on Windows Neovim uses
`AppData\Local`. Some dirs exist only on Linux: `state_dir()` and `executable_dir()` return nothing
on macOS and Windows.

= Options
- *Whether it exists:* no `mdot.dirs` in v1 (Claude's recommendation), or add it.
- *Which dirs:* a short list (`home`, `config`, `data`, `cache`), or all of them.
- *Names:* the crate's (`config_dir`), or without the `_dir` suffix (`config`).
- *Implicit specs:*
  - A. Keep ADR 0020: always `~/.config/<name>`.
  - B. `mdot.dirs.config .. "/<name>"`: follows `XDG_CONFIG_HOME` on Linux, but sends every
    implicit spec to `~/Library/Application Support` on macOS.
  - C. `$XDG_CONFIG_HOME` or `~/.config` on every OS, a rule only implicit specs follow.
- *A dir that does not exist on this OS:* `nil`, or an error.

= Decision
From the author:

- *`mdot.dirs` exists, "just to get the common dirs".* The author's reason: by the principle that
  mdot ships no database of where software keeps its config, the user should know that a program
  such as Neovim keeps its config somewhere else on another OS. A spec handles that by checking the
  OS itself, for example with `mdot.os.name` (not designed here).
- *It holds all the dirs,* not a short list.
- *Names drop the `_dir` suffix:* `mdot.dirs.config`.
- *Implicit specs: option A.* ADR 0020 is unchanged; implicit specs link to `~/.config/<name>`.
- *A dir that does not exist on this OS is `nil`.*

Claude's argument for A, which the author agreed with: an implicit spec is a shortcut for the
common case and behaves the same on every machine; a directory that needs another location gets a
`spec.lua` using `mdot.dirs`.

Accepted additions proposed by Claude:

- *The list is fixed in `design.typ`,* 19 names: `home`, `cache`, `config`, `config_local`,
  `data`, `data_local`, `executable`, `preference`, `runtime`, `state`, `audio`, `desktop`,
  `document`, `download`, `font`, `picture`, `public`, `template`, `video`. Each value is what the
  `dirs` crate's function of the same name plus `_dir` returns on this OS. A crate upgrade does not
  change the list.
- *Unknown names are an error:* reading a name not in the list (`mdot.dirs.confg`) is an error
  naming the field, as for `mdot.os` (ADR 0040). `nil` means only "this dir does not exist on this
  OS", so `mdot.dirs.state or mdot.dirs.data_local` works.
- *Read-only:* writing to `mdot.dirs` is an error naming the file.
- *Readable from `config.lua`, host files and specs.* A dir used in `config.lua`'s vars makes base
  `vars` differ per machine; that is the user's fault (ADR 0039), and `design.typ` warns about it,
  as for `mdot.os.hostname`.
- *`--host` does not change `mdot.dirs`:* they are always the real machine's dirs.
- *Values are absolute path strings without a trailing separator,* so paths are joined as
  `mdot.dirs.config .. "/nvim"`.
- *mdot resolves the dirs before loading.* Specs still cannot read the environment (ADR 0013).

= Consequences
- Closes the `mdot.dirs` part of ADR 0038's open item on other members. ADR 0038 and ADR 0020 are
  unchanged.
- Answers another part of ADR 0013's open "Host and OS info".
- A spec can place a file in a per-OS location without string expansion in `dst`, as ADR 0020
  suggested.
- Implicit specs still ignore `XDG_CONFIG_HOME` and are usually wrong on Windows; such a directory
  needs a `spec.lua`.
- Choosing a location per OS needs `mdot.os.name`, which stays open.
]
