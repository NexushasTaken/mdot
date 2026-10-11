#import "../template.typ": adr

#adr(number: 24, title: [`net.download` fetches one pinned file], status: [Proposed], date: [2026-10-11])[
= Context
ADR 0023 left `net.download` open: the diff needs something stable to compare, and specs stay pure
(ADR 0013). The author's Yolk setup has two downloads (`research.typ`, the Yolk section): a kanata
binary pinned to a version, and a cursor theme tarball fetched from `latest`. Neither has a checksum.
Both already exist as packages, so the clause is a fallback for things no package provides.

= Options
- Hash optional, or recorded on first download (trust on first use). Easy to write, but the desired
  state is then unknown until the network is touched, and the plan cannot be offline.
- Hash required in the spec. The desired state is `(url, sha256)`, known without the network.
  Chosen.
- Fetch at spec load time to learn the hash. Breaks ADR 0013.

= Decision
- Form: `net.download { url = "...", dst = "...", sha256 = "..." }`. All three are required.
  `dst` expands like `file.link`'s (ADR 0020).
- The resource is a regular file at `dst`, with its sha256 as the identity. The recorded state
  (ADR 0009) stores that hash.
- Spec loading and `plan` never use the network. `plan` compares hashes only. The network is used
  during `apply`.
- Apply downloads to a temporary file next to `dst`, checks the sha256, then renames over `dst`. A
  mismatch deletes the temporary file, leaves `dst` untouched and fails that resource.
- Decision table (desired hash `D`, recorded hash `R`, live file hash `L`):

  #table(
    columns: (auto, 1fr),
    [Situation], [Action],
    [`dst` missing], [create],
    [`L == D`], [no-op, record `D`],
    [`L != D` and `L == R`], [update (the file is ours and out of date)],
    [`L != D` and `L != R`, or no record], [conflict (ADR 0016); someone else changed it],
  )
- Removal: remove `dst` only if `L == R`. Otherwise leave it and report it, as for links (ADR 0011).
- Same-`dst` rules (ADR 0021) and conflicts (ADR 0016) apply as for any resource (ADR 0023).
- One optional argument, `mode` (for example `"755"`), because the kanata case is useless without
  the execute bit. It is applied before the rename and is not part of the identity.
- Not in this ADR: archive extraction, mirrors or fallback URLs, a download cache, authentication
  and proxies. Retries are left out of v1; a failed download fails the resource.

= Consequences
- Updating a download means editing both `url` and `sha256`. That is the price of an offline plan.
  A helper such as `mdot hash <url>` to print the hash is useful, but is a separate decision.
- A tarball such as the cursor theme cannot be used until extraction is designed. Use the package
  (`phinger-cursors` in the AUR) meanwhile.
- The `dst` file is a real file, so the rollback problem with symlinks (RQ4) does not apply.
- Not in Phase 1. This ADR only fixes the shape so the resource model does not rule it out.
- Open: whether `mode` belongs on `file.copy` too, and should be a shared option. Decide with
  `file.copy`.
- Open: whether a changed `mode` alone (same hash) is an update. Left undecided.
]
