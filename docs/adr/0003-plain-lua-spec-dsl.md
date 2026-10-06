# ADR-0003: Plain-Lua, lazy.nvim-style spec DSL

- Status: Accepted
- Date: 2026-10-06 (spec style originally from the earlier design session)

## Context
The author wants a DSL for specs. Candidates were a custom syntax with its own parser, a DSL embedded
in Lua, or an existing config language (KDL/HCL). sol2 is already part of the stack.

## Options
1. Custom syntax + own parser (+ tree-sitter grammar for editors).
2. Lua-embedded DSL.
3. Existing config language plus our semantics.

## Decision
Option 2, with the author's constraint: **do not modify Lua syntax to make the DSL.** A spec is
`spec { clause, clause, ... }`, where every clause (`name`, `depends`, `enabled`, `config`, `render`,
`patch`, `sysfile`, `on_remove`) is an ordinary function call returning a tagged table. Style follows
lazy.nvim specs. `name(str, { pkg, pkg_alts })` is kept from the earlier session.

## Consequences
- No parser to write; full Lua available for per-host logic.
- Readability rests entirely on API design.
- Metatable use is limited to `dirs.<root>["path"]` indexing.
- Requires a sandbox (ADR-0013).
