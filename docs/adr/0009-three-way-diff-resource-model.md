# ADR-0009: Resource model with a 3-way diff

- Status: Proposed
- Date: 2026-10-06

## Context
The author wants plan/diff, status/drift and adopt, and asked how a diff can work when configs are
symlinks (a symlinked file's content always equals the repo).

## Decision
Specs compile into resources (`Link`, `Render`, `Patch`, `SysFile`, later `Package`). The planner
compares **desired** (specs) × **recorded** (state) × **live** (system) per resource and emits
create / update / delete / noop / conflict (decision table in design.md §9.2). For `Link`, mdot owns
only the link's existence and target; content history belongs to git, and `mdot status` shows both.

## Consequences
- Removal and drift detection become possible because recorded state exists.
- Users see two layers (mdot resources + git content); whether that is understandable is RQ3.
