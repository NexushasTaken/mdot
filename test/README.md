# test: ~/dotfiles-v2 in the new mdot layout

Layout experiment only; nothing here is runnable yet.

- `hosts/nexos.lua` is the root: only specs it reaches through `depends` are applied.
  `specs/desktop`, `utils` and `dev-utils` are groups (a `spec.lua` with only `depends`).
  `legacy` (old i3/X11 stuff), `alacritty` and `rofi` are not reached, so they are not applied.
- No `spec.lua` = implicit spec: the directory is linked to `~/.config/<name>`.
- `spec.lua` present = explicit spec: only the listed `link()` calls apply.
  Used when the target is not `~/.config/<name>`, is a single file, or the
  target dir is shared with other programs (gh, cargo, krita, systemd-user).

## Not ported (the design can't express it yet)

- Package installs (pacman/paru lists in nexos, utils, dev-utils, tablet; per-app
  `package.install`): packages are Phase 5, not designed.
- Package-only specs: flatery-icon, fluent-gtk-theme, phinger-cursors, opentabletdriver.
- Comtrya plugins/scripts (aur.lua, git.lua, install-comtrya.sh).
- Comtrya `variables` (git name/email, font, cursor): no `vars` yet.
- Legacy `unmanaged/` install scripts and the duplicate `.bashrc`/`.bash_profile`
  (superseded by the bash spec), plus the loose `~/.config/picom.conf`
  (duplicate of picom/picom.conf).
