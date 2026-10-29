# mdot

mdot is a declarative dotfile manager. You describe which files go where in a git repo of small
Lua files, and mdot makes your home directory match: it creates symlinks, keeps track of what it
made, and removes what you no longer ask for. It never overwrites a file it didn't create.

```
$ mdot plan
bash
  + link  ~/.bashrc -> bashrc
nvim
  + link  ~/.config/nvim -> config

Plan: 2 to create.

$ mdot apply
apply? [y/N] y
bash
  + link  ~/.bashrc -> bashrc
nvim
  + link  ~/.config/nvim -> config

Applied: 2 created.
```

## Documentation

1. [Getting started](getting-started.md): install mdot and deploy your first dotfiles.
2. [The repo](repo.md): how a dotfiles repo is laid out, and specs with and without `spec.lua`.
3. [Writing specs](specs.md): `file.link`, `depends`, and helper functions.
4. [Hosts and variables](hosts-and-vars.md): one repo, several machines; `config.lua` and
   `mdot.vars`.
5. [The `mdot` table](lua-api.md): `mdot.os`, `mdot.dirs`, `mdot.vars`, `mdot.print`, and what
   Lua can and cannot do in a spec.
6. [Commands](commands.md): `plan`, `apply`, `preview`, `specs`, flags and exit codes.
7. [How mdot manages files](managing-files.md): what mdot owns, conflicts, removing things, and
   where it keeps its state.
8. [Troubleshooting](troubleshooting.md): every error and conflict, and how to fix it.

## The ideas in one minute

- **Your repo is the truth.** Each directory in `specs/` is a *spec*: a program's config files plus
  an optional `spec.lua` that says where they go.
- **Each machine picks its specs.** `hosts/<hostname>.lua` lists the specs this machine wants. Specs
  nobody asks for are not deployed.
- **`plan` before `apply`.** `mdot plan` shows what would change and touches nothing. `mdot apply`
  does it.
- **mdot only changes what it made.** If something else is in the way, or a link mdot made was
  changed by hand, mdot stops and tells you. Nothing is overwritten.
- **Edits go straight to the repo.** Your config files are symlinked, so editing
  `~/.config/nvim/init.lua` edits the file in your repo. Commit as usual.
