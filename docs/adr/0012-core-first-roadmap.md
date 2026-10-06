# ADR-0012: Core config manager first; packages and extras later

- Status: Accepted
- Date: 2026-10-06

## Context
Candidate v1 features: hooks, lockfile, native AUR source, system scope. The author: design the core
config manager (user and system configs) first, then add hooks, lockfile, package-manager handlers.
Multi-OS support should be designed generically but researched later.

## Decision
Phases 1–4 are the core (links/state/plan → adopt/removal/generations → system scope → tree-sitter).
Phase 5 adds package providers (pacman). Phase 6+ adds AUR, hooks, lockfile, secrets, units/groups,
other platforms. The `PackageProvider` interface is defined early so the resource model accounts for it.

## Consequences
- Until phase 5, specs declare packages but mdot does not install them.
- Research experiments (research.md §7) run before Phase 1 is locked.
