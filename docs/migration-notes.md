# Migration notes (dotfiles-v2 -> mdot)

## Now (Phase 1, links only)
- [x] First-run conflict: old symlinks point into ~/dotfiles-v2.
Simplest: a one-off script that unlinks them. No design change.

## Before Phase 5 (layout rules, decide before creating dirs)
- [ ] Package-only specs (~30): single-file spec or package.list?
- [ ] Config + package with same name: accept spec.lua boilerplate?

## Later
- [ ] AUR / paru / kanata-bin: keep in a bootstrap script until Phase 6
- [ ] Packages go before links within a spec
- [ ] XDG_CONFIG_HOME or hardcode ~/.config
- [ ] Krita rewrites kritarc (drift) -> patch in Phase 4
- [ ] Kanata system parts stay in unmanaged/

## Housekeeping
- [ ] Redo research.typ translation appendix (old syntax)
  - [ ] Add the ADR 0024 row to the table in adr/main.typ
