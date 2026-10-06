# ADR-0008: Tree-sitter structural editing instead of templating

- Status: Accepted (strictness rules: Proposed)
- Date: 2026-10-06

## Context
Configs need per-host values (e.g. `font`, `cursor` from `Comtrya.yaml`), and some apps rewrite their
own config. The author rejected find/replace templating and proposed tree-sitter queries that locate
and modify nodes, "like jq, but for any config format".

## Decision
One tree-sitter query+edit engine with three uses, all chosen by the author:
- `render()` — repo base file + edits → managed copy;
- `patch()` — enforce specific nodes in an app-owned live file;
- `mdot query` — standalone jq-like CLI.
Queries and edits are written directly in the spec.

Proposed strictness rules: zero matches for `set` is an error (use `ensure` to add); multiple matches
are an error unless `all = true`; the edited file must re-parse without ERROR nodes or nothing is
written.

## Consequences
- Base files stay valid configs the app can read.
- Depends on grammar availability per format (kanata `.kbd` has none).
- Reliability on real files is unproven — research question RQ1, experiments S1/S2.
