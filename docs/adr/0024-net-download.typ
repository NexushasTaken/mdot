#import "../template.typ": adr

#adr(number: 24, title: [`net.download` fetches one pinned file], status: [Proposed], date: [2026-10-11])[
= Context
ADR 0023 left `net.download` open: the diff needs something stable to compare, and specs stay pure
(ADR 0013). The author's Yolk setup has two downloads (`research.typ`, the Yolk section): a kanata
binary pinned to a version, and a cursor theme tarball fetched from `latest`. Neither has a checksum.
Both already exist as packages, so the clause is a fallback for things no package provides.

Files can be large (gigabytes) and mdot may run on slow machines, so reading a whole file to hash it
on every `plan` or `status` is not acceptable.

= Options
- Hash optional, or recorded on first download (trust on first use). Easy to write, but the desired
  state is then unknown until the network is touched, and the plan cannot be offline.
- Fetch at spec load time to learn the hash. Breaks ADR 0013.
- Hash required in the spec. The desired state is `(url, sha256)`, known without the network.
  Chosen.
- Hash the live file on every `plan`. Exact, but slow on large files and slow machines. Rejected.
- Record the file's stat next to its hash and compare stats in `plan`; hash only in `apply` and in
  an explicit `verify` command. Chosen.

= Decision
- Form: `net.download { url = "...", dst = "...", sha256 = "..." }`. All three are required.
  `dst` expands like `file.link`'s (ADR 0020).
- The resource is a regular file at `dst`, with its sha256 as the identity.
- Spec loading and `plan` never use the network. The network is used during `apply`.
- *Hashing happens in two places only.*
  - `apply` computes the sha256 while the bytes are written to a temporary file next to `dst`
    (incremental hashing, no second pass). On a mismatch it deletes the temporary file, leaves
    `dst` untouched and fails that resource. On a match it renames over `dst`.
  - `mdot verify` (below).
  - `plan`, `status` and the checks inside `apply` never read file contents.
- *Recorded state* (ADR 0009) for this resource is the hash `R` that `apply` verified, plus the
  file's `size`, `mtime_ns` and `inode` right after the rename.
- *Plan.* "Stat matches" means the live file's size, mtime and inode equal the recorded ones. It
  says the file is unchanged since mdot wrote it, so `R` still describes it. With the desired hash
  `D` from the spec:

  #table(
    columns: (auto, 1fr),
    [Situation], [Action],
    [`dst` missing], [create],
    [recorded, stat matches, `R == D`], [no-op],
    [recorded, stat matches, `R != D`], [update (the file is ours and out of date)],
    [stat differs, or no record], [conflict (ADR 0016): "changed or unknown, run `mdot verify`"],
  )

  The cheap check can say "unchanged" but never "equal". When unsure it reports a conflict, and
  `apply` never overwrites a conflict.
- *`mdot verify`* hashes the files `plan` reported as conflicts (or every download with a flag that
  ignores the stat cache). For each file with live hash `L`:
  - `L == D` or `L == R`: refresh the recorded stat (and `R = L`). The file was fine, only its
    metadata moved. The conflict disappears. When there was no record, this adopts the file.
  - otherwise: report the file as modified. Nothing is changed on disk.

  So `verify` writes state, but never touches `dst`.
- Removal: remove `dst` only if there is a record and the stat matches it. Otherwise leave the
  file and report it, as for links (ADR 0011). `verify` first if you want it removed.
- Same-`dst` rules (ADR 0021) and conflicts (ADR 0016) apply as for any resource (ADR 0023).
- One optional argument, `mode` (for example `"755"`), because the kanata case is useless without
  the execute bit. It is applied before the rename and is not part of the identity.
- Not in this ADR: archive extraction, mirrors or fallback URLs, a download cache, authentication
  and proxies. Retries are left out of v1; a failed download fails the resource.

= Consequences
- `plan` and `status` cost one `stat` call per download, whatever its size.
- After `rsync`, a backup restore or `cp` without `-p`, mtimes change, so every download shows as a
  conflict until `mdot verify` runs once. Content changes that keep size, mtime and inode are only
  found by a full `verify`. Git's index makes the same trade.
- Updating a download means editing both `url` and `sha256`. That is the price of an offline plan.
  A helper such as `mdot hash <url>` to print the hash is useful, but is a separate decision.
- A tarball such as the cursor theme cannot be used until extraction is designed. Use the package
  (`phinger-cursors` in the AUR) meanwhile.
- The `dst` file is a real file, so the rollback problem with symlinks (RQ4) does not apply.
- Not in Phase 1. `verify` is built together with `net.download`. This ADR only fixes the shape so
  the resource model does not rule it out.
- Open: whether the stat record and `verify` are generic, so `file.copy` (and later `sysfile`) use
  them too. Decide with `file.copy`.
- Open: whether `mode` belongs on `file.copy` too, and is a shared option.
- Open: whether a changed `mode` alone (same hash) is an update. Left undecided.
]
