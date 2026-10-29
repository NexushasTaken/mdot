#import "../template.typ": adr

#adr(number: 57, title: [Classify compares each pair on its own; live vs desired is optional], status: [Accepted], date: [2026-10-26])[
= Context
ADR 0035's `classify` uses one `match(a, b)` for all three pairs, and names the live state `both`
when live matches desired and live matches recorded. That assumes desired, recorded and live have
the same shape. For links they do (a `src` on each side, ADR 0030). For downloads (ADR 0032) they do
not:

- live is one `stat`, never a hash, because `plan` never reads file contents (ADR 0024);
- recorded has the content key `R`, the hash `W` of the written bytes and the stat (ADR 0024,
  ADR 0026);
- desired has the content key `D` and the optional `mode`, and no stat.

So live can be compared with recorded, but not with desired. With live vs desired always "no match",
three of the 13 cases (`planner.typ`) cannot be reached for downloads: new/desired, match/both and
differ/desired. And a download with nothing to do (stat matches, `R == D`) lands on match/recorded,
which the generic table maps to *update* instead of *noop*.

ADR 0035 also left open whether "same / differ" is enough, since ADR 0032 has three rows where the
file is unchanged and still desired: noop, `chmod` only, and download again.

= Options
For the missing live vs desired comparison:
- *The download's `decide` maps match/recorded to noop.* The case would say "recorded" when all
  three agree, and every later kind with the same limit would need the same override.
- *An "unknown" live state.* Honest, but every kind's table gets more cases.
- *Define `both` from live vs recorded and desired vs recorded.* Chosen.

For `chmod` only vs download again:
- *The comparison returns more than match / differ*, carried in the case.
- *The case stays match / differ;* the kind picks the kind of update from the step's values. Chosen.

For a spec-only `mode` change: `chmod` only, or download again. `chmod` only.

= Decision
From the author:
- *`classify` uses three comparisons,* one per pair: desired vs recorded (`dr`), live vs recorded
  (`lr`) and live vs desired (`ld`). The sides can have different shapes. For links all three have
  the same shape, so all three comparisons exist. For `net.download` live and desired cannot be
  compared, so `ld` can be absent.
- *`both` is `lr` and `dr`.* When live matches the record and the record matches desired, live and
  desired count as equal; `ld` is not needed for it.
- *A spec-only `mode` change on a download* (stat matches, `R == D`, desired `mode` differs from the
  recorded one) is an update that changes only the live file's mode and the record. This keeps
  ADR 0026. `mode` is not part of the identity (ADR 0024).

Accepted additions:
- *"Same / differ" is enough.* The case stays `match` / `differ`. The kind picks the kind of update
  (`chmod` only or download again) after `decide`, from the desired and recorded values the step
  carries. Both are an update in ADR 0032, so the decision is the same; only how it runs differs.
- *No `ld`, no adopt.* A kind without `ld` never gets `live = "desired"`, so `plan` never adopts it.
  For downloads adopting stays with `mdot verify` (ADR 0024).
- *What the download comparisons read.* `dr` compares the content key (`R` vs `D`) and `mode`. `lr`
  compares the stat (`size`, `mtime_ns`, `inode`, permission bits). Desired has no stat.
- *Downloads use the same `decide` as links* (`links_like_decide` in `planner.typ`). Checked by
  running it: it gives ADR 0032's result for all of its rows. A kind may still have its own table.

The pseudocode is in `planner.typ`.

= Consequences
- Refines ADR 0035: its definition of `both` ("live matches both") is replaced, and its single
  `match` becomes three comparisons. ADR 0035 is kept as history.
- For links nothing changes: `match` is equality, so `lr` and `dr` imply `ld`. All 13 link cases of
  ADR 0030 give the same result (checked by running it).
- For downloads the unreachable cases are new/desired and differ/desired, the two adopt cases. They
  are the cases only hashing could answer, which `mdot verify` does.
- Closes ADR 0035's open item "Is 'same / differ' enough?".
- File attributes (`chattr`) are not managed or compared.

= Open
- Whether cases a kind's table does not list default to conflict (ADR 0035).
- How the differently shaped values are typed in Rust (ADR 0035). This ADR fixes only that there are
  three comparisons and that `ld` is optional.
- Trait or enum (ADR 0035, ADR 0036).
- Whether `mode` is written as a number instead of a string (ADR 0026 uses `mode = "755"`). Lua has
  no octal literals, so `mode = 755` is decimal 755. A separate decision.
]
