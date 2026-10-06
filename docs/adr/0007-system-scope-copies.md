# ADR-0007: System-scope files are root-owned copies, not symlinks

- Status: Proposed
- Date: 2026-10-06

## Context
The author wants both user and system configs managed. The user-scope model is symlinks into the repo.
The repo is user-writable.

## Decision
Targets under system roots (`dirs.etc`, `sysfile()`) are deployed as **copies** with explicit owner,
group and mode, never as symlinks. Privileged steps are batched and executed via one
`sudo mdot --exec-plan <file>` re-exec.

## Consequences
- Avoids a privilege-escalation path (root-read config pointing at a user-writable file).
- Editing a system config in place no longer updates the repo; changes must go through the repo and
  `apply`. Drift on these files is detected by hash.
- Systemd units, groups and users remain out of scope.
