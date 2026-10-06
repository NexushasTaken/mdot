# ADR-0010: Git-based generations and rollback

- Status: Accepted
- Date: 2026-10-06

## Context
The author wants NixOS-like generations and rollback. Options discussed: snapshot files + package
set, files + exact package versions, files only. The author proposed a git-diff-based approach.

## Decision
A generation records the applied commit SHA, a dirty flag, host, time, and the deployed resource list
(`$XDG_STATE_HOME/mdot/<repo-id>/generations/NNNN.json`). `mdot rollback [N]` creates a git worktree
at that commit, loads specs from it, plans against current state, confirms, and applies.

## Consequences
- No content store; the repo history is the history.
- Generations applied from a dirty tree are not exactly reproducible (warned).
- Restoring *content* of symlinked files is unresolved, because links point into the working tree —
  research question RQ4, experiment S5.
