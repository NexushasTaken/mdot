#import "../template.typ": adr

#adr(number: 71, title: [`mdot preview <host>` replaces `plan --host`: `plan`'s format against an empty machine], status: [Accepted], date: [2026-10-28])[
= Context
`--host <name>` made `plan` load `hosts/<name>.lua` instead of the real host file, as a dry run, and
`apply` with a different `--host` was an error (ADR 0019). Only `mdot.os.hostname` follows it
(ADR 0040); every other `mdot.os` field and `mdot.dirs` describe the real machine (ADR 0043, ADR
0044). ADR 0065 left this open as a limitation. ADR 0047 lists `--host` as a global flag, ADR 0064
says it applies to `plan` only, and ADR 0065 makes `specs --host` the way to inspect another host.
ADR 0070 gives `--host` its naming rules.

Facts that shaped it:

- `plan --host` diffed the other host's desired state against *this* machine's live files and
  `state.json`. For another machine that gives wrong rows: no change or a conflict where this
  machine already manages a path, and a removal for a path this machine manages but the other host
  does not want.
- `specs` reads only the repo: it takes no lock (ADR 0063), and nothing in its output (ADR 0065)
  comes from state.
- The author's use case: configuring Termux on their phone from the PC, because using the phone for
  hours strains their hands.

= Options
- *The limitation:* keep `plan --host` and document the limitation; give `--host` an exact preview
  (pretend `mdot.os` and `mdot.dirs` too); or replace `plan --host` with a subcommand.
- *Output of the subcommand:* the desired state as a list; a real diff against this machine; or
  `plan`'s format diffed against an empty machine.
- *Name:* `show`, `preview`, `eval`.
- *`specs --host`:* keep it, drop it, or fold it into the subcommand.

= Decision
From the author:

- *`--host` is removed from `plan`,* and with it `apply`'s error for a `--host` that differs from the
  real hostname.
- *A new subcommand, `mdot preview <host>`,* works like `plan` but never changes any file. Its
  purpose is to preview what would show if the host were different. The name was picked from
  Claude's list; the author's reason: it describes itself.
- *`mdot.os` and `mdot.dirs` stay this machine's values under `preview`.* The author's reason: its
  only purpose is to preview.

Claude's proposals, accepted by the author:

- *Output: `plan`'s format, diffed against an empty machine.* `preview` reads only the repo: no live
  files, no `state.json`, no state directory and no lock. Every resource shows as what a fresh
  machine would get. Claude's reason: a diff against this machine's live files and state shows
  wrong rows for another machine.
- *`specs --host` is kept* (accepted once Claude checked that `specs` reads no state and takes no
  lock). Claude's reason: `--host` was only misleading where it faked a diff; `specs` has none.

```
termux
  + link  ~/.termux/termux.properties -> specs/termux/termux.properties
bash
  + link  ~/.bashrc -> specs/bash/bashrc
```

Accepted additions proposed by Claude:

+ *Name rules:* ADR 0070's `--host` rules apply to `preview`'s `<host>` and to `specs --host`: an
  uppercase name is an error, a format break is a warning, an unsafe name is an error. In
  `preview`'s messages, `--host "x"` reads `host "x"`.
+ *`<host>` is required:* `mdot preview` without a name is a usage error. Previewing the real host
  is `mdot preview <its name>`.
+ *Missing host file:* `preview typo` with no `hosts/typo.lua` is ADR 0067's missing-name error,
  exit 2, listing the files in `hosts/`.
+ *`mdot.os.hostname`* is `<host>` under `preview`, as it was under `--host` (ADR 0040).
+ *Warnings:* `preview` never reads the real hostname, so it shows no hostname warning. It picks a
  host file, so the `hosts/` bad-file warnings still show (ADR 0070).
+ *`--host` is not a global flag:* it exists only on `specs`.
+ *Streams and exit codes* are `plan`'s (ADR 0050, ADR 0053). With an empty machine there is no
  conflict from live files or state.
+ *Missing hostname message:* ADR 0070's error becomes
  `error: cannot determine the hostname; set one`, since `plan` and `apply` no longer take
  `--host`. Setting a hostname was already the only fix for `apply`.

= Consequences
- Supersedes the `--host` parts of ADR 0019 (`plan --host` and the `apply --host` error), ADR 0047
  and ADR 0064 (where `--host` applies), and ADR 0067's `--host <name>` case, which becomes `preview
  <name>` and `specs --host <name>`. ADR 0040's definition of `mdot.os.hostname` holds with
  `<host>` in place of the `--host` value. ADR 0070's rules for `--host` cover `preview <host>` too.
- Closes ADR 0065's open item on `mdot.os` under `--host`: under `preview`, OS branches and
  `mdot.dirs` use this machine's values, and `~` expands to this machine's home. A per-host
  difference written in the host file (`depends`) previews accurately; an `mdot.os.name` branch in a
  spec does not.
- `preview` needs no repo lock and creates no state directory, unlike `plan` (ADR 0063).
- The planner must be able to diff the desired state against an empty live and recorded state.
]
