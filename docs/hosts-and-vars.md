# Hosts and variables

## Host files

Each machine has a file `hosts/<hostname>.lua`. It is where mdot starts: everything this machine
gets is reached from here through `depends`.

```lua
-- hosts/laptop.lua
return spec {
  depends("desktop", "bash", "nvim"),
}
```

A host file may only:

- select specs with `depends`;
- change values in `mdot.vars` (below).

`file.link` in a host file is an error: a host file has no directory for `src` to be relative to.
Put links in a spec.

### Which host file is used

`plan` and `apply` always use this machine's hostname:

| OS      | Name used |
|---------|-----------|
| Linux   | the kernel hostname (`cat /proc/sys/kernel/hostname`) |
| macOS   | the local hostname (Settings → General → Sharing → Local hostname) |
| Windows | the DNS hostname (`hostname` in a terminal) |

The name is lowercased and used as is. `nexos.lan` selects `hosts/nexos.lan.lua`; the domain is not
trimmed.

- Host file names must be lowercase. A file with uppercase in its name can never be selected, and
  mdot warns about it.
- A hostname with characters outside `a`–`z`, `0`–`9`, `-` and `.` gets a warning, and mdot goes
  on.
- No host file for this machine is an error that lists the files in `hosts/`.
- An empty hostname, or one that is `.`, `..` or contains `/` or `\`, is an error. Set a proper
  hostname.

To see what another machine would get, use `mdot preview <host>` (see [Commands](commands.md)).

### Specs nobody reaches

A spec that no host reaches is not deployed. If it was deployed before (you removed it from
`depends`), the next `mdot plan` shows its links as removals.

`mdot specs` lists the specs this machine reaches and, at the end, the ones it doesn't:

```
$ mdot specs
bash
  needed by:  laptop (host)
nvim
  needed by:  laptop (host)
not reached: alacritty, rofi
```

## `config.lua` and `mdot.vars`

Variables are values that specs read and machines can change: a font name, a cursor size, your
git email.

They are defined once, in `config.lua` at the repo root:

```lua
-- config.lua
mdot.vars.font = "Hack Nerd Font"
mdot.vars.cursor = { name = "phinger-cursor-dark", size = 16 }
mdot.vars.fonts = { "Hack", "Noto Sans" }
```

A host file may change existing values:

```lua
-- hosts/tablet.lua
mdot.vars.cursor.size = 24
return spec { depends("desktop") }
```

Specs read them:

```lua
-- specs/hypr/spec.lua
local cursor = mdot.vars.cursor.name
```

The order is always `config.lua`, then the host file, then the specs. `config.lua` only sets
variables: it must not return anything.

### The rules

mdot takes the *types* from `config.lua` and checks the host's changes against them. This means a
spec can rely on a value having the same type on every machine.

| In `config.lua` | Allowed in a host file |
|---|---|
| a string, number or boolean | another value of the same type (integers and decimals are both "number") |
| a record: `{ name = "x", size = 16 }` | change its fields; not add new ones or remove existing ones |
| a list: `{ "A", "B" }` | change its length (even to empty) and its elements, keeping the element type |
| a list of records | every record must have the same fields and types as the first one in `config.lua` |

Not allowed in `config.lua`:

- an empty table `{}`: give a list at least one element;
- a table with both list items and named fields: `{ "A", x = 1 }`;
- a list with holes: `{ "A", nil, "C" }`;
- a function or any other non-data value.

Specs can't change variables at all: `mdot.vars.font = "x"` in a spec is an error.

Every problem is reported in one run, each with the file and the variable's path:

```
error: hosts/tablet.lua: mdot.vars.cursor.size: expected number, got string
error: hosts/tablet.lua: mdot.vars.cursor.colour: not in config.lua; a host may only override existing vars
```

### Keep `config.lua` the same everywhere

`mdot.os` and `mdot.dirs` work in `config.lua`, but using them there makes the base values differ
between machines. Put per-machine differences in the host files.
