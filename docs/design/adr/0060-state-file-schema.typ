#import "../template.typ": adr

#adr(number: 60, title: [`state.json` is a versioned flat resource list with top-level `created_dirs`], status: [Accepted], date: [2026-10-27])[
= Context
`design.typ` showed only the generation record (Phase 2). Phase 1 needs the shape of `state.json`
itself: what a link record holds, how created parent directories are stored, and a format version.

Constraints:
- ADR 0059: JSON via `serde` + `serde_json`. Writes are atomic (temp file, then `rename`).
- ADR 0034: records are matched to desired resources by ID; a record must hold enough to act without
  its spec.
- ADR 0054: the ID is computed (`<kind>:<output>`), not stored.
- ADR 0055: the record stores the owning spec as a plain field.
- ADR 0056: paths are expanded, absolute and lexically normal.
- `link-rules.typ`: the string written into a symlink is the absolute, normalized `src`.
- `design.typ`, Parent directories: missing parents are created and recorded, removed deepest first
  with `rmdir` semantics; a directory that is not empty is left alone and dropped from state.
- ADR 0032: a download record must fit the same shape later.

= Options
*Created parent directories:*
+ *Per record* (a `directories` list on each link record). Leaks: if specs `a` and `b` both link
  into a new `~/.config/foo/`, only `a`'s record lists `foo`. Removing `a` fails the `rmdir` (b's
  file is there) and drops it; removing `b` later leaves an empty `foo` forever.
+ *Top-level list with a stored reference count.* No leak, but the count duplicates what the records
  already say and can drift from them.
+ *Top-level list, usage derived from the records.* Chosen.

*Format version:* refuse, migrate or ignore a file of another version. Ignoring unknown fields loses
them on the next write, so it was not considered further.

= Decision
From the author:
- *`state.json` is one object with `"version": 1` and a flat `resources` list.* Each item has a
  `kind` and that kind's own fields. The generation record's `resources` list can reuse it.
- *A link record* holds `kind`, `spec`, `src` and `dst`. `src` and `dst` are absolute.
- *Downloads* use the same list with their own fields (ADR 0032's content key `R`, written hash `W`
  and stat); the exact fields are decided when downloads are built.
- *Created directories are a top-level `created_dirs` list,* not part of any record. Whether a
  directory is still used is derived: it is used while any record's `dst` is under it. No count is
  stored.
- *A file that does not parse, or has no `version`, is a hard error* (exit 2, ADR 0053).

Claude's recommendation, accepted by the author:
- *A missing `state.json` is empty state* (first run).
- *A `version` newer than this mdot knows is refused:* "state.json is version N; this mdot reads up
  to M. Upgrade mdot." Exit 2. mdot neither reads nor writes it.
- *An older `version` is migrated on read,* in memory, one version at a time, and saved as the
  current version on the next write. Each version bump ships a migration from the version before it.

```
load_state(path):
  if file missing:              return empty state
  parse JSON, else:             error, exit 2
  v = field "version", else:    error, exit 2
  if v == CURRENT:              return it
  if v >  CURRENT:              error "upgrade mdot", exit 2
  if v <  CURRENT:              migrate v -> v+1 -> ... -> CURRENT, in memory
```

*Cleaning up `created_dirs`* runs after the delete phase (ADR 0054):

```
for d in created_dirs, deepest first:
  if no record in resources has a dst under d:
    rmdir d     # already gone: done
    remove d from created_dirs
```

Example:

```json
{
  "version": 1,
  "created_dirs": ["/home/nexus/.config/foo"],
  "resources": [
    { "kind": "link", "spec": "a",
      "src": "/home/nexus/dotfiles/specs/a/a.conf",
      "dst": "/home/nexus/.config/foo/a.conf" },
    { "kind": "link", "spec": "b",
      "src": "/home/nexus/dotfiles/specs/b/b.conf",
      "dst": "/home/nexus/.config/foo/b.conf" }
  ]
}
```

Accepted additions:
+ *Field names are `src` and `dst`*, as in the spec, the plan output and the ADRs.
+ *Two records with the same ID are a hard error* (exit 2). Matching by ID (ADR 0034) assumes one
  record per ID; only a bug or a hand edit can cause it.
+ *A record with a `kind` this mdot does not know is a hard error* (exit 2). Ignoring it would drop it
  on the next write.
+ *`created_dirs` paths are absolute and lexically normal* (ADR 0056), so the "under `d`" check
  compares one spelling.
+ *A directory that is not empty* (or whose `rmdir` fails for another reason) is left, warned about
  and dropped from `created_dirs`, as `design.typ` already says. Otherwise mdot would warn about it on
  every `apply`.

= Consequences
- The shared-parent leak is gone: a created directory is removed once the last record under it is.
- `design.typ`'s Parent directories and State sections now name `created_dirs` and show the file.
- Downgrading mdot after a format bump stops it from running until it is upgraded again. Nothing is
  lost.
- A crash between `mkdir` and the state write still leaves an unrecorded empty directory (ADR 0029).

= Open
- *How the `on_remove` policy is stored:* on each record or per spec (ADR 0011, ADR 0055). Next todo
  item.
- *The repo-id and locking* (`design.typ`, State and generations).
- *The exact download fields* (ADR 0032).
- *What a migration does in detail;* no version 2 exists yet.
]
