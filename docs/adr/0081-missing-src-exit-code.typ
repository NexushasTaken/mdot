#import "../template.typ": adr

#adr(number: 81, title: [A missing or dangling `src` exits with 2], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0015 makes a missing `src` an error at load time, and ADR 0021 lists it among the plan errors
that stop `apply` before the first write. No ADR gives it an exit code. ADR 0067 made every missing
spec or host name 2 ("like reading a file that does not exist") and left `src` out on purpose.
ADR 0080 runs right after this check and gives 1 to a `src` that exists but resolves outside its
spec directory.

ADR 0053 draws the line as: 1 means mdot finished its checks and the answer is no; 2 means mdot
could not finish. A missing `src` sits on that line: mdot does not read the file at load time, it
only asks the OS whether the path exists and gets a clear "no".

#table(
  columns: 3,
  [*Case*], [*Code*], [*Source*],
  [`depends("waybr")`, no `specs/waybr/`], [2], [ADR 0067],
  [`src = "../bar/x"` (exists, outside the spec)], [1], [ADR 0080],
  [`src = "conifg"` (typo, does not exist)], [?], [this ADR],
  [two specs with the same `dst`], [1], [ADR 0053],
  [a Lua syntax error in `spec.lua`], [2], [ADR 0053],
)

A `src` can also be a symlink in the repo whose target is gone (`specs/foo/theme ->
../theme-old`, with `theme-old` deleted): the link itself exists, but following it finds nothing,
and ADR 0080's check has nothing to resolve.

= Options
- *Missing `src`:* 1 (ADR 0053's line: the checks can finish, so it is a refusal), or 2 (the OS
  reports that the file does not exist, as with names in ADR 0067).
- *Dangling symlink as `src`:* counts as missing, or counts as existing (leaving ADR 0080's check
  undefined and deploying a link to a link that leads nowhere).

= Decision
From the author:

- *A missing `src` exits with 2.* The author's reason: the OS cannot read it, or reports that the
  file does not exist.
- *A dangling symlink is a missing `src`,* so it exits with 2 too.

Accepted additions proposed by Claude:

+ *Other `stat` failures:* a `src` whose existence cannot be checked (such as permission denied or
  an I/O error) is also 2; mdot could not finish (ADR 0053).
+ *Error text:* `error: <spec>: src "<as written>" does not exist`, followed by
  `(symlink target missing: <target>)` when `src` is a dangling symlink.
+ *Batch form:* applies to every link the batch form expands to (ADR 0022).
+ *Why not 1:* a missing `src` is 2 even though mdot's checks can finish. This follows ADR 0067's
  precedent for missing names rather than the wording of ADR 0053's line between 1 and 2.

```
load file.link(src, dst) in spec <spec>:
    norm = lexical_normalize(<repo>/specs/<spec>/<src>)         # ADR 0056
    if norm does not exist, or is a symlink whose target is gone,
       or its existence cannot be checked:
        error: <spec>: src "<src>" does not exist [(symlink target missing: <target>)]  # exit 2
    check norm stays inside specs/<spec>/                       # ADR 0080, exit 1
```

= Consequences
- Closes ADR 0080's open item (the exit code for a missing `src`).
- Every "does not exist" case, a name (ADR 0067) or a `src` (this ADR), exits with 2. A `src` that
  exists but breaks a rule (ADR 0080) stays 1.
- Unchanged: plan still reports every error it finds (ADR 0021), and 2 wins over 1 (ADR 0053).
- `design.typ`'s Exit codes paragraph lists a missing or dangling `src` under 2. ADRs 0015 and 0080
  are not edited; ADR 0080's index status notes that this ADR closes its open item.
]
