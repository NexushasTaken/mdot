#import "../template.typ": adr

#adr(number: 61, title: [No removal policy; removed resources follow their kind's table], status: [Accepted], date: [2026-10-27])[
= Context
ADR 0011 gave each spec an `on_remove { files = "remove"|"ask"|"keep", package = "uninstall"|"ask"|"keep" }`
policy, with defaults from `mdot.opt` (ADR 0045), and proposed storing the effective policy in state
at apply time. ADR 0060 left open how it is stored, and ADR 0058 left open how it reaches `decide`:
`decide(case)` sees only the case, but under `keep` the case removed / recorded must give `forget`
instead of `delete` (ADR 0054).

For links, the only kind in Phase 1, the policy does little: a link's content is in the repo, so a
link kept after its spec directory is deleted is a dangling symlink.

Research (2026-10-27):
- *Dotfile managers:* none found has a per-resource removal policy. home-manager and dotter delete a
  file dropped from the config on the next activation / deploy, and only if it is still theirs
  (home-manager: still a link into a generation; dotter: target as expected). The way to keep a file
  is to keep it in the config. Guix home removes the previous generation's links. chezmoi is the
  opposite: it keeps by default and deletes only via `chezmoi remove` or `.chezmoiremove`.
- *Infrastructure tools* have it, per resource: Pulumi `retainOnDelete` (set in advance, inherited
  from the parent), Helm's `helm.sh/resource-policy: keep` annotation (honored only if it was in the
  last deployed manifest), and Terraform's `removed { lifecycle { destroy = false } }` (written at
  removal time). Their documented uses are resources that hold data or that others depend on:
  databases, DNS zones, volumes, CRDs, handing a resource to another team or tool.
- No request from a dotfile-manager user for a per-file keep was found.

= Options
- *Keep the policy, stored on each record or per spec* (ADR 0060's open item). Ways it could reach
  `decide`:
  + *A:* `decide` also receives the record and reads the policy in its removed / recorded row.
  + *B:* `decide` is unchanged; a step after it rewrites the action (`delete` under `keep` becomes
    `forget`).
  + *C:* the policy is part of the case. Rejected in discussion: the generic `classify` would have to
    know about policies.
- *Per-clause policy:* each resource clause chooses its own; `config.lua` / host only set the default.
- *No policy.* Chosen.

= Decision
From the author:
- *Drop the `on_remove` policy.* It is added in the future only if it is actually needed or has a
  real use case.
- If it is revived, the author preferred *B* over A, because a new kind's `decide` then cannot forget
  to handle the policy. (A per-kind B step can still be forgotten; only a generic one avoids it, and
  a generic one cannot see kind-specific fields such as `installed_by_mdot`. Not settled.)

Accepted additions:
+ *Supersedes ADR 0011.*
+ *A removed resource gets its kind's table action and nothing else.* For a link: removed /
  recorded is `delete`, removed / other is a conflict, removed / absent is `forget`.
+ *`design.typ`:* the `on_remove.*` rows of `mdot.opt`, the planned `on_remove {}` clause and the
  "(per `on_remove`)" notes are removed; the plan example says `(spec removed)`; the Removal policy
  section points here.
+ *If a policy is added later,* the state version bump (ADR 0060) fills old records with the
  behavior they were applied under: delete. Nothing has to be guessed.
+ *The research and the A / B / C options are kept here* so a future design does not start from zero.

= Consequences
- Closes ADR 0060's open item on how the policy is stored, and the `on_remove` half of ADR 0058's
  open item. ADR 0054's rule for `keep` no longer arises; under this ADR a freed slot comes from a
  `delete` only.
- The link record stays `kind`, `spec`, `src`, `dst` (ADR 0060).
- To keep a resource, keep it in a spec, as in home-manager and dotter.
- `design.typ`'s download table loses its open question about a stat mismatch under `keep`.

= Open
- *What removing a package does* (uninstall, ask, or keep) is decided when packages are designed
  (ADR 0028, Proposed). ADR 0011's `package = "ask"` default no longer exists.
- *`mdot.opt` has no options left.* The mechanism (ADR 0045) stays; whether an empty table is fine,
  or the mechanism waits for its first option, is open.
- ADR 0058's open item on a package's `installed_by_mdot` still stands.
]
