# Getting started

## Install

mdot is built with Cargo:

```sh
cargo install --path /path/to/mdot
```

That puts the `mdot` binary in `~/.cargo/bin`. Check it runs:

```sh
mdot --version
```

## Make a repo

A dotfiles repo needs two directories: `specs/` for your configs and `hosts/` for your machines.

```sh
mkdir -p ~/dotfiles/specs ~/dotfiles/hosts
cd ~/dotfiles
git init
```

## Add a config

The simplest spec is a directory with your config files in it. Move your Neovim config in:

```sh
mv ~/.config/nvim ~/dotfiles/specs/nvim
```

A directory **without** a `spec.lua` is linked as a whole to `~/.config/<its name>`. So
`specs/nvim/` will become `~/.config/nvim`.

For a file that doesn't live in `~/.config`, write a `spec.lua`. For `~/.bashrc`:

```sh
mkdir ~/dotfiles/specs/bash
mv ~/.bashrc ~/dotfiles/specs/bash/bashrc
```

```lua
-- specs/bash/spec.lua
return spec {
  file.link("bashrc", "~/.bashrc"),
}
```

`file.link(src, dst)` says "make `dst` a symlink to `src`". `src` is relative to the spec's
directory.

## Pick what this machine gets

mdot only deploys the specs a host asks for. Find your hostname:

```sh
cat /proc/sys/kernel/hostname   # Linux
```

Create `hosts/<hostname>.lua` (lowercase). If your machine is called `laptop`:

```lua
-- hosts/laptop.lua
return spec {
  depends("nvim", "bash"),
}
```

## Plan and apply

Run every command from the repo root (or pass `--repo ~/dotfiles`).

```
$ mdot plan
nvim
  + link  ~/.config/nvim -> .
bash
  + link  ~/.bashrc -> bashrc

Plan: 2 to create.
```

`plan` never changes anything. If it looks right:

```
$ mdot apply
apply? [y/N] y
nvim
  + link  ~/.config/nvim -> .
bash
  + link  ~/.bashrc -> bashrc

Applied: 2 created.
```

Run `plan` again and there is nothing left to do:

```
$ mdot plan
No changes.
```

## If something is in the way

If `~/.bashrc` still exists as a regular file, mdot won't replace it:

```
$ mdot plan
bash
  ! link  ~/.bashrc -> bashrc
conflict: ~/.bashrc: regular file, not managed by mdot

Plan: 1 to create, 1 conflict.
```

Move or delete the file yourself, then plan again. `apply` refuses to run while any conflict is
left, so a half-finished apply can't happen. See
[How mdot manages files](managing-files.md#conflicts).

## Next

- [The repo](repo.md): the layout in detail.
- [Writing specs](specs.md): more ways to link files.
