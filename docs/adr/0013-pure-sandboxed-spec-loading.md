# ADR-0013: Spec loading is pure and sandboxed

- Status: Proposed
- Date: 2026-10-06

## Context
Specs are full Lua (ADR-0003). The author wants `plan` to show what will happen before anything does.

## Decision
`config.lua` and each spec file run in a fresh `sol::environment` without `os.execute`, `io`,
arbitrary `load`, or `debug`; `require` is restricted to the repo. Read-only helpers `env()` and
`exists()` are provided.

## Consequences
- `mdot plan`/`status` cannot have side effects caused by spec code.
- Globals cannot leak between spec files.
- Per-host logic is limited to the exposed context — whether that suffices is RQ5.
