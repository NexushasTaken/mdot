# mdot - Multi purpose DOTfile manager

**mdot** is a multi purpose dotfile manager, it leverages the functionality of
some parts of popular dotfile and project managers.

An mdot configuration purpose is to make a reproducable system - categorized in
scopes - in archlinux, and possibly to support other OS's, like Ubuntu and
Windows.

## Configuration

*Configurations* are written in lua, which makes it easier to configure the scope.

The *Main Configuration* is where the actual definitions of configurations and packages for that scope.
Each *Main Configuration* must return a table that must match the structure defined in [Package Spec](./config_spec.md).

> i specifically said "implicitly" and "explicitly", see below for examples (see [Package](#package)).

For the rest of this document, we will be using `mdot/<path>` which an alias for `$XDG_CONFIG_HOME/mdot/<path>`(*User Scope*).
> TODO: What about for other scopes? the System Scope and Project Scope?

### Package

Each element in the table (key-value pair) is considered a *Package*, whether its just a string, key-value paired or just a table, a *Package* can implicitly/explicitly defines how the package is configured.

all *Package* configurations must be located in `mdot/pkgs/<package-name>`, for example:
```
~/.config/mdot/pkgs/bash/
├── bashrc.sh
├── bash_profile.sh
└── prompt.sh
```

When you define a package in the table array like:
```lua
return {
  { "bash" },
}
```
> see [Package Fields](#package-fields) `name` field for more info on how to specify the name for package.

All package configs will automatically be linked and insert all the entries in `links` like so:
> This is similar GNU Stow behavior.
```lua
return {
  "bash",
  links = {
    "bashrc.sh",
    "bash_profile.sh",
    "prompt.sh",
  },
}
```
Use `exclude` field to specify this field to which what files to be ignored by automatic links.
> see [Package Fields](#package-fields) `links` field for more info.
The insertion of all entries will always happen even if you have specified the field `links`, for example:
```lua
return {
  {
    "bash",
    links = {
      ["bashrc.sh"] = "~/.bashrc",
    },
  },
}
```
internally, the links will become:
```lua
{
  "bash",
  links = {
    ["bashrc.sh"] = "~/.bashrc",
    "bash_profile.sh",
    "prompt.sh",
  },
}
```

### Package Fields

- `name` - It must be a string and also a valid filepath
  - This is used as identifier for that package.
  - It is used to locate the sources and targets of that package configurations

**Ways to specify the name of the package**

```lua
return {
  "bash", -- By the string itself
  { "bash" }, -- Wrapping the string in a table (note, the name must be on the first index of the table)
  bash = {}, -- Using *key* as a name
  { name = "bash" },

  -- regardless of what used above, the package will translate to:
  { name = "bash" },

  -- specifying in the name using all of those ways will result in error:
  bash = { "bash", name = "another-name-or-bash" },
}
```

- `default_target` - This is used for resolve the package source dotfile in `links`
This field is always defaults to `$XDG_CONFIG_HOME/<package-name>/`

- `links` - This is used to link the dotfiles from source to targets
The source will always be relative to `mdot/pkgs/<package-name>/`, for example, `bashrc.sh` is located in `mdot/pkgs/bash/bashrc.sh`

There are many ways to make a link:

1.
```lua
return {
  {
    "bash" -- name of the package

    --- By config path as string
    links = { "bashrc.sh" }, -- this file is located in "mdot/pkgs/bash/bashrc.sh"

    -- Doing the way above will normalize that element into:
    links = {
      ["bashrc.sh"] = {
        "<default_target>/bashrc.sh", -- basically, its "~/.config/bash/bashrc.sh"
      }
    },


    ["bashrc.sh"] = "~/.bashrc", -- using key-value pairs as source to target

    ["bashrc.sh"] = { "~/.bashrc", "~/.config/bash/bashrc.sh"}, -- using key-value pairs as source to targets, but the targets is an array
  }
}
```

- `excludes` - specify this field to which what files to be ignored by automatic links.
  Glob can be used, like `*`.

for example:
```lua
{
  "bash",
  excludes = "bash_*.sh",
}
```
This results in
```lua
{
  "bash",
  links = {
    "prompt.sh",
    -- Both of these files will not be included, as it matches the excludes glob.
    -- "bashrc.sh",
    -- "bash_profile.sh",
  },
  excludes = "bash*.sh",
}
```
You can also use an array of exclude globs like so:
```lua
{
  "bash",
  links = {}, -- `links` is then will be empty
  excludes = { "bash*.sh", "prompt.sh" },
}
```
Note that using `"*"` in `excludes`, will disable the automatic links, as it
matches all files, you then had to manually link the configs; use this if you
want more control to linking the configs.

> TODO: Still not sure how `depends` will affect `enabled`
- `depends` - just like how literrary packages works, packages has dependencies.
if the package1 depends on another package2, package2 will be installed(its configs will be linked).
the dependencies of a packages must be enabled, but if any dependencies are disabled, error will be thrown;
unless, DependencySpec is specified instead of regular Package definition.

Example:
```lua
return {
  "fish",
  {
    "alacritty",

    -- "fish" package is required for "alacritty", disabling "fish" package will result in error
    depends = { "fish" },
    -- The definition above, translate to
    depends = { { "fish", type = "required" } },

    -- "fish" package is optional and "fish" package can be disabled
    depends = { { "fish", type = "optional" } },
  },
}
```

- `enabled` - This controls if the package should be installed or not.
  Defaults to `true`

- `platforms` - Specify the supported platforms which the package is only available

If the current platform, lets say "Windows", but the supported platforms is only "Linux", then the package is technically disabled, hence, error will be thrown.

Example of managing dotfiles for Hyprland setup.

`mdot/init.lua`
```lua
return {
  "alacritty",
  {
    "hyprland",
    depends = {
      "git", -- Source Code Management
      "alacritty", -- Terminal emulator
      "bash", -- Shell for terminal
      "waybar", -- Bar for hyprland
    },
  },
  {
    "git",
    links = {
      ["config"] = "~/.gitconfig", -- link the "config" file from "~/.config/mdot/pkgs/git/" to "~/.gitconfig"
    },
    excludes = ["*", "user.conf"],
  },
  {
    "bash",
    default_target = "~", -- put everything inside home directory, literrary GNU Stow behavior
  },
}
```

## Scopes - Configuration levels

**Scopes** is a per specific configurations levels on a System, Home(or User)
and Project. The configuration defines what packages and configurations it
needed for that scope.

- *System Scope* is a system wide configuration, to which how the system is
configured like the system packages and programs configurations.
  - This is an mdot configuration that makes the system reproducable, by
  specifying specific which packages are should be installed and program
  configurations.

- *Home Scope* or *User Scope* is a per user configuration, each user in a
system can have their own configuration on how they setup their environments,
and what packages and program configurations they have.
  - This is where dotfiles comes in, users typically have dotfiles which
  contains configurations, by having mdot configuration, they can easily setup
  and manage their environment.

- *Project Scope* is a per project configuration to which makes building
project from source easily.
  - Instead of the developer looking at the documentation of the project on how
  to build the source code by changing specific configurations, installing
  packages; the dev can just use the mdot *Project Scope* to automate the setup
  to build the project from source code.

### System Scope

### Home Scope or User Scope

The configuration directory is located at `$XDG_CONFIG_HOME/mdot`(or `~/.config/mdot`).
The `$XDG_CONFIG_HOME/mdot/init.lua`, is where the real main configuration lives.

### System Scope

## Miscellanious

The **mdot** manager took inspirations from popular softwares, the list
includes:

- [Yolk](https://elkowar.github.io/yolk/book/getting_started.html)
- [GNU Stow](https://www.gnu.org/software/stow/)
- [Nix Flakes](https://nixos.wiki/wiki/flakes) and [Home Manager](https://github.com/nix-community/home-manager)
- [Lazy - Folke](https://lazy.folke.io/)
