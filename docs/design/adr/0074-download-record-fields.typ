#import "../template.typ": adr

#adr(number: 74, title: [A download record stores its normalized `url`; a changed `url` downloads again], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0060 left the exact download fields of `state.json` open. ADR 0032 and `design.typ` already name
what a download record holds: the content key `R`, the sha256 of the written bytes `W`, and the stat
(`size`, `mtime_ns`, `inode`, permission bits). Until now the content key was the hash when verified
and the `url` when `verify = false`, so changing only the `url` of a verified download was a noop.

`net.download` is not part of Phase 1. It is decided now so that the format is frozen before work
continues without Claude (`.claude/CLAUDE.md`, Endgame).

Constraints:
- ADR 0034: a record holds enough to act without its spec.
- ADR 0054: the ID is `download:<dst>` and is computed, not stored. The `url` never changes which
  record a resource matches; it only changes the result for a matched pair.
- ADR 0055, ADR 0056: the record stores `spec`; `dst` is absolute and lexically normal.
- ADR 0026: the stat record is one mechanism shared with `file.copy`.

Tested with the `url` crate 2.5.8 (`Url::parse`, then printing it): scheme and host are lowercased,
a default port is dropped, dot segments are removed, an empty path becomes `/`, surrounding
whitespace is trimmed, a space is encoded as `%20`, and a Unicode host becomes punycode.
Percent-encoding is left as written (`%7E` stays, `%7e` is not uppercased). A URL with no scheme
(`example.org/a`) is rejected. `set_fragment(None)` removes `#...` and keeps the query and an
encoded `%23`; `https://example.org/a#x` then compares equal to `https://example.org/a`.

= Options
*A `url` change on a verified download:*
+ *Noop,* as before. The hash already pins the bytes. The stored `url` would then be either stale or
  one that was never fetched.
+ *Download again.* Chosen.

*How `R` is stored:* one tagged string (`"sha256:<hex>"` or `"url:<url>"`), or separate `url` and
`hash` fields. Separate fields, since both are now compared.

*Credentials in the `url`:* refuse a password only, or refuse any userinfo (`user@` or
`user:pw@`).

= Decision
From the author:
- *The record stores the `url`, and a changed `url` downloads again,* for verified downloads too.
  Two different URLs might give different files, and a value that is not saved cannot be compared.
- *A `url` with a password in the spec is a load error.* The `user:password` form is deprecated
  (RFC 3986, section 3.2.1).

Accepted additions proposed by Claude (reasons are Claude's):
+ *`url` is normalized:* parsed with `Url::parse`, and its printed form is stored and compared. A
  `url` that does not parse is a load error.
+ *`hash` is `"<algo>:<hex>"` in lowercase hex,* or `null` when `verify = false`. `sha256 = "x"` is
  stored as `"sha256:x"`, so both spec forms have one spelling.
+ *The record shape:* `written` is `"sha256:<hex>"`. The stat is a nested `stat` object, so
  `file.copy` can reuse it. `stat.mode` is an octal string such as `"755"` holding `st_mode & 0o7777`,
  the same format as the spec's `mode`. `size`, `inode` and `mtime_ns` are JSON integers;
  `mtime_ns` is signed (before 1970 it is negative). serde_json reads 64-bit integers exactly; tools
  that read JSON numbers as doubles round `mtime_ns`, which matters only when reading the file by
  hand.
+ *The fragment is dropped* after parsing, before storing and comparing. It is never sent to the
  server, so `.../kanata#readme` and `.../kanata` fetch the same file.
+ *Any userinfo is a load error,* not only a password. A token often sits in the user slot
  (`https://<token>@github.com/...`), and mdot cannot tell a token from a name. A plain download
  has no use for a username alone.

*The content key* is now the pair (normalized `url`, `hash`). ADR 0032's table is unchanged: `R` is
the recorded pair, `D` the desired one, and `R != D` means download again.

```
desired.url  = normalize(spec url)    # Url::parse; drop fragment;
                                      # userinfo or no parse: load error
desired.hash = "<algo>:<hex>" or null # null when verify = false

R != D  when  record.url != desired.url  or  record.hash != desired.hash
```

Example:

```json
{ "kind": "download", "spec": "kanata",
  "dst": "/home/nexus/.local/bin/kanata",
  "url": "https://example.org/kanata",
  "hash": "sha256:abc123",
  "written": "sha256:abc123",
  "stat": { "size": 1048576, "mtime_ns": 1761638400123456789,
            "inode": 393217, "mode": "755" } }
```

= Consequences
- Supersedes ADR 0032's definition of the content key (the hash alone when verified). Its table
  stays.
- A `url` edit is fetched and checked on the next `apply`. A new `url` that serves other bytes fails
  the hash check then, and `dst` is left alone.
- The stored `url` is always one that produced the recorded bytes.
- Moving a download to a mirror costs one fetch.
- Two spellings that differ only in percent-encoding (`%7E` vs `~`) still compare as different and
  download again.
- `mode` is still not part of the content key; a `mode` change alone runs only `chmod`.

= Open
- *Authenticated downloads:* how a private download gets its credentials without putting them in the
  `url`. Not designed.
]
