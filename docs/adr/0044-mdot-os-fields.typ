#import "../template.typ": adr

#adr(number: 44, title: [`mdot.os` describes the real machine: name, family, arch and comtrya's fields], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0040 gave `mdot.os` one field, `hostname`, which follows `--host`, and left other fields to be
designed when a real spec needs one. ADR 0043 needs one: a spec that places a program's config per
OS checks the OS itself, for example `mdot.os.name == "linux"`. `mdot.dirs` always describes the
real machine (ADR 0043), and a dir that does not exist on this OS is `nil`.

The author's comtrya setup has an `os` context with `bitness`, `codename`, `distribution`,
`edition`, `family`, `hostname`, `name` and `version`. In comtrya's `lib/src/contexts/os.rs`, `name`
and `family` are Rust's `std::env::consts::OS` and `FAMILY` (`linux`, `windows`, `macos`,
`android`; `unix`, `windows`). The others come from the `os_info` crate's display strings (read in
its current source; comtrya pins 3.14): `distribution` is a display name such as `Arch Linux` or
`Mac OS`, `bitness` is `64-bit`, `version` is `Rolling Release` on Arch, and a missing value is
`"unknown"`, `"Unknown"` or `"unknown bitness"`. `bitness` does not tell x86_64 from ARM; Rust's
`std::env::consts::ARCH` does.

= Options
- *Which fields:* only `name`; the fields every OS has (`name`, `family`, `arch`); or comtrya's
  list.
- *Missing values:* a string such as `"unknown"`, or `nil`.
- *Value format:* display names (`"Arch Linux"`), or lowercase ids (`"arch"`).
- *Bitness and arch:* `bitness` only, `arch` instead of it, or both.
- *Under `--host`:* the fields can be pretended, or always describe the real machine.

= Decision
From the author:

- *`mdot.os` has comtrya's fields:* `bitness`, `codename`, `distribution`, `edition`, `family`,
  `hostname`, `name`, `version`. `name` holds values such as `windows`, `linux`, `macos`,
  `android`.
- *A value that does not exist on this OS is `nil`.*
- *Values are lowercase ids.*
- *`arch` is added.*
- *Under `--host`, the fields describe the real machine.*

Accepted additions proposed by Claude:

- *`name`, `family` and `arch`* are Rust's values: `name` as `std::env::consts::OS`, `family` as
  `FAMILY` (`unix`, `windows`), `arch` as `ARCH` (`x86_64`, `aarch64`, `x86`, `arm`, …).
- *`distribution`:* on Linux, the `ID=` value of `/etc/os-release` as written (`arch`, `debian`,
  `ubuntu`). On other OSes it is `nil`, since `name` already says which OS it is. mdot keeps no
  table of distro names (no built-in knowledge).
- *`bitness`* is a number, `32` or `64`, or `nil` if unknown.
- *`version`* is a string as the OS reports it (`"10.0.22631"`, `"14.5"`), or `nil` when there is
  no version, as on Arch's rolling release.
- *`codename` and `edition`* are strings as the OS reports them, or `nil` when there is none (both
  are `nil` on Arch). They are names or free text, not a fixed set mdot could turn into ids.
- *`hostname` is the exception:* `design.typ` says it is the only `mdot.os` field that follows
  `--host` (ADR 0040).
- *ADR 0040's rules cover the new fields:* read-only, an unknown field is an error naming it,
  readable from `config.lua`, host files and specs, and the same warning that using them in
  `config.lua`'s vars makes base `vars` differ per machine.

= Consequences
- Closes the `mdot.os` part of ADR 0038's open item on other members, and ADR 0040's "other fields"
  consequence. ADR 0038 and ADR 0040 are unchanged.
- Answers another part of ADR 0013's open "Host and OS info".
- A spec can choose a location per OS (`mdot.os.name`) or a download per CPU (`mdot.os.arch`).
- `plan --host laptop` on a Linux machine still sees `mdot.os.name == "linux"`, even if the laptop
  runs another OS; only the host file and `hostname` are pretended.
- Which crate or method reads the values is an implementation choice, not fixed here.
]
