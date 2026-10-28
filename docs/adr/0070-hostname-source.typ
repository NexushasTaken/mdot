#import "../template.typ": adr

#adr(number: 70, title: [The hostname comes from the OS's stable name, lowercased; bad names warn, unsafe ones are errors], status: [Accepted], date: [2026-10-28])[
= Context
mdot picks `hosts/<name>.lua` by the real hostname unless `--host` is given (ADR 0019), and
`mdot.os.hostname` is exactly that `<name>` (ADR 0040). Nothing said where the real hostname comes
from. Cross-platform is a goal, so the name must be stable and predictable on Linux, macOS and
Windows. Facts that shaped it:

- *Linux:* the kernel's name (`gethostname()`, `uname -n`) and the saved name in `/etc/hostname`
  are usually equal; they differ after a manual `hostname foo` until reboot. The kernel accepts any
  bytes up to 64 (tested: `my_box` and `Weird Name!` were accepted, 65 bytes was rejected). systemd
  only accepts letters, digits, `-` and `.` in `/etc/hostname` and filters out other characters
  (`valid_ldh_char` in systemd's `hostname-util.c`; `hostname(5)`). So `_` reaches the kernel only
  by hand or on a non-systemd init.
- *macOS:* three names: `ComputerName` (free text), `LocalHostName` (Bonjour label, DNS-safe,
  derived from `ComputerName`, editable in Settings → General → Sharing) and `HostName` (usually
  unset). With `HostName` unset, `gethostname()` follows the network (DHCP, reverse DNS, VPNs), so
  the name can change between networks. Apple's DTS advice ("On Host Names", Apple Developer
  Forums) is to avoid `gethostname()` and to read `SCDynamicStoreCopyLocalHostName`, which returns
  the label without `.local` and can return NULL. nix-darwin's README names configs after
  `scutil --get LocalHostName`; its code and Home Manager's use `hostname -s`.
- *Windows:* a DNS hostname that keeps its case, and a NetBIOS name (`GetComputerNameW`,
  `%COMPUTERNAME%`) that is uppercase and cut to 15 characters. The domain is a separate field.
- DNS names are case-insensitive. Linux filesystems are case-sensitive; APFS and NTFS are not by
  default, so an exact name would match `hosts/nexos.lua` on macOS and Windows but not on Linux,
  while `mdot.os.hostname` kept the OS's case.
- ADR 0050: warnings and errors go to stderr as `<word>: <message>`, a message about a file starts
  with its path, and `hint:` lines are not in the first version.

= Options
- *macOS source:* `gethostname()` as-is, `LocalHostName`, or require `HostName` to be set.
- *Linux source:* `/etc/hostname` or `gethostname()`.
- *Domain part:* keep it, or cut at the first `.`.
- *Case:* exact, or lowercase.
- *A real hostname that breaks the format:* an error, a warning, or per OS (warning on Linux, error
  elsewhere).

= Decision
From the author:

- *No trimming.* The name is used exactly as the OS stores it: `nexos.lan` selects
  `hosts/nexos.lan.lua`. The author's reason: that is exactly what `/etc/hostname` contains.
- *Host names are strictly lowercase.* The real hostname is lowercased. A `--host` value must be
  lowercase; uppercase is an error.
- *A real hostname that breaks the format is a warning, not an error,* shown whenever mdot runs.
  The author's reason: Linux allows such names, so mdot does too.
- *Files in `hosts/` that break the rules are reported as warnings, not errors:* a name with
  uppercase (which can never match) and a name that breaks the format.

Claude's recommendations, adopted by the author without reasons of their own:

- *Sources:* Linux `gethostname()` (the kernel's live name); macOS `LocalHostName`; Windows the DNS
  hostname. Claude's reasons: on Linux it is what `uname -n` and the prompt show, it works the same
  on every init system, and systemd does not let DHCP override a set static name; on macOS
  `LocalHostName` is always set, stable across networks, filename-safe, edited in Sharing, and is
  Apple's advice. The macOS choice was confirmed by web research at the author's request.
- *One check on every OS* instead of a Linux-only exception, so a name the OS accepted is never
  refused. `--host` gets the same format warning, so a machine named `my_box` can be previewed with
  `--host my_box`.
- *An unsafe file name is an error* for both the real hostname and `--host`: empty, `.`, `..`, or
  containing `/` or `\`. The kernel accepts such names, and they would load a file outside `hosts/`.

```
host_name(source):
    name = source.value
    if source is real:  name = lowercase(name)
    if source is --host and name has uppercase:  error
    if name is empty, ".", "..", or contains "/" or "\":  error
    if name breaks the format:  warning, continue
    load hosts/<name>.lua
```

Accepted additions proposed by Claude:

+ *Windows:* the DNS hostname (`GetComputerNameExW` with `ComputerNameDnsHostname`), not the
  NetBIOS name or `%COMPUTERNAME%`.
+ *Lowercasing* changes only ASCII `A`–`Z`.
+ *Unavailable name:* an empty or unavailable hostname (such as macOS returning no
  `LocalHostName`) is an error that suggests `--host`.
+ *Warning frequency:* the hostname warning shows once per run, only when the real hostname is read
  (`plan`, `apply` and `specs`, including `specs <name>`), never under `--host`.
+ *The format is RFC 1123:* `a`–`z`, `0`–`9` and `-`; labels of 1–63 characters separated by
  `.`; no `-` at the start or end of a label; at most 253 characters in total.
+ *`mdot.os.hostname`* holds the final, lowercased name, so it still equals the `<name>` in
  `hosts/<name>.lua` (ADR 0040).
+ *`apply --host`:* the check that `--host` equals the real hostname compares against the
  lowercased real hostname.
+ *Read once:* the hostname is read once at startup and used for the whole run.
+ *When `hosts/` is checked:* on every run that picks a host file (`plan`, `apply`, `specs`, with or
  without `--host`), with one warning per bad file, naming it.

*Messages* (Claude's wording, accepted by the author):

#table(
  columns: 2,
  [*Situation*], [*Message*],
  [Real hostname breaks the format],
  [`warning: hostname "my_box" is not a valid hostname (only a-z, 0-9, '-' and '.')`],
  [`--host` breaks the format],
  [`warning: --host "my_box" is not a valid hostname (only a-z, 0-9, '-' and '.')`],
  [A file in `hosts/` has uppercase],
  [`warning: hosts/Laptop.lua: host file names must be lowercase; this file is never used`],
  [A file in `hosts/` breaks the format],
  [`warning: hosts/my_box.lua: "my_box" is not a valid hostname (only a-z, 0-9, '-' and '.')`],
  [`--host` has uppercase], [`error: --host "Laptop": host names must be lowercase`],
  [Unsafe name],
  [`error: hostname "../x" cannot be used as a file name` (`--host "../x"` for `--host`)],
  [Hostname unavailable or empty],
  [`error: cannot determine the hostname; set one or pass --host <name>`],
)

The name is quoted so an empty name, spaces or a trailing `.` stay visible. The messages list the
allowed characters instead of citing RFC 1123, so they say how to fix the name; they leave out the
length and `-` placement rules to stay short. The hostname warning does not say how to rename the
machine, since that is OS-specific.

= Consequences
- Closes the "Hostname source" item. Answers another part of ADR 0013's open "Host and OS info".
  ADR 0040 is unchanged: its definition of `mdot.os.hostname` still holds, now with a lowercased
  name.
- `hosts/` file names are lowercase. On macOS and Windows, where default names have capitals
  (`DESKTOP-7F3K2QJ`, `Nexuss-MacBook-Air`), the file is the lowercased name.
- A Mac's host file follows Settings → General → Sharing → Local hostname, not the name shown in
  the shell prompt when `HostName` is unset.
- mdot is stricter on macOS than nix-darwin's and Home Manager's code (`hostname -s`), and agrees
  with nix-darwin's README.
- Reading `LocalHostName` and the Windows DNS name needs OS-specific calls; the `hostname` crate
  and Rust's `std` only call `gethostname()`. Which crate or method is used is an implementation
  choice.
- The missing host file error (design.typ, ADR 0067) is unchanged.

= Open
- Exit codes for the three errors (ADR 0053 gives 2 for an error and 1 for a broken rule; which
  applies to an uppercase `--host` was not discussed).
]
