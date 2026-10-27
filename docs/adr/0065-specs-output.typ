#import "../template.typ": adr

#adr(number: 65, title: [`mdot specs` output and `<spec-name>`], status: [Accepted], date: [2026-10-27])[
= Context
`design.typ`'s CLI table listed `mdot specs` as "list the specs the current host reaches, in
dependency order (debugging)", with no arguments, and its output was never designed. It is in Phase
1.

Selection starts at `hosts/<hostname>.lua` (or `--host`) and follows `depends`; a spec reached more
than once is applied once, an implicit spec is a leaf, and unknown names and cycles are load errors
(ADR 0019). Under `--host <name>`, `mdot.os.hostname` is `<name>` (ADR 0040). `specs` takes no lock
(ADR 0063). Normal output goes to stdout and diagnostics to stderr with a lowercase word (ADR 0050).
`plan` already groups by spec name in dependency order (ADR 0051). Exit codes are ADR 0053.

= Options
- *Scope:* A. the current host only (`hosts/<hostname>.lua` or `--host`); B. every file in
  `hosts/`, each run on this machine.
- *All hosts:* a separate command, a flag on `specs` (e.g. `--all-hosts`), or no all-hosts view.
- *Load error:* 1. print only the error, as `plan` does; 2. print the error, then what did load.
- *Cycles:* allow them (the visited set that applies a spec once already stops loading from
  looping; dependency order would lose its meaning), or keep them as errors.

= Decision
From the author:

- *Each spec shows both directions:* what it depends on, and what needs it (other specs or the
  host).
- *Scope A by default:* the current host only. `--host <name>` inspects another host.
- *No all-hosts view.* The author first chose a flag on `specs` in Phase 1, then removed it
  entirely. `--host <name>` is the way to inspect another host.
- *Unreached specs are shown* too.
- *An optional `<spec-name>` argument:* `mdot specs` shows all specs; `mdot specs <spec-name>` shows
  only that one. The author noticed the command had no argument.
- *Load errors, option 2:* the error, then whatever loaded.
- *Cycles stay errors* (ADR 0019 unchanged).

Accepted additions proposed by Claude (accepted as a whole, without reasons of their own):

+ *Layout:* each spec's name is a heading, followed by indented `depends on:` and `needed by:`
  lines. A host appears as `<name> (host)`. Empty lines are left out. Specs come in dependency
  order.
+ *Unreached section:* after the reached specs, one line `not reached: <names>`, sorted. These are
  the directories in `specs/` the host does not reach; their `spec.lua` is not run, so a broken
  unused spec cannot break `specs`.
+ *Unknown `<spec-name>`:* an error that lists the known names, as a missing host file does. A name
  that exists but is not reached is shown as not reached.
+ *Streams:* the listing goes to stdout, errors to stderr with ADR 0050's `error:`.
+ *Marking partial output:* a `depends` name that does not exist appears as `<name> (missing)` in
  `depends on:`.
+ *Exit code:* the code the error gives under ADR 0053 (an unknown name or a cycle 1, a Lua error
  2), even though partial output was printed.

Example (`laptop` depends on `desktop` and `bash`, `desktop` on `hypr` and `waybar`; `rofi` exists
but nothing depends on it):

```
$ mdot specs
hypr
  needed by:  desktop
waybar
  needed by:  desktop
desktop
  depends on: hypr, waybar
  needed by:  laptop (host)
bash
  needed by:  laptop (host)
not reached: rofi
```

= Consequences
- `specs` answers "why is X applied?", "what does X pull in?" and "why isn't X applied?" for one
  host. "Which hosts use X?" needs one `--host <name>` run per host.
- Option 2 means the loader must keep what it loaded before an error instead of discarding it.
- The CLI table in `design.typ` gains `<spec-name>`.

= Open
- Under `--host`, the `mdot.os` fields other than `hostname` still describe the
  real machine (the same limitation `--host` already has).
- The exit code for an unknown `<spec-name>` argument (ADR 0053 does not say whether it is a usage
  error).
- The order of specs with no dependency relation between them, within dependency order.
- Later phases: package ownership (ADR 0028) and `pkg_alts` introspection (`research.typ`).
]
