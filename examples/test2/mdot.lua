return {
  "git",
  {
    name = "hyprland",
    enabled = false,
    depends = {
      { "git", "required" },
      "waybar",
    },
    links = {
      ["bashrc.sh"] = { "~/.bashrc" },
    },
    excludes = "config",
  },
  neovim = {
    enabled = function() return true end,
    depends = {
      { "vim", "required" },
      { "git", "required" },
    },
    platforms = "linux",
    excludes = { "config", "user" },
  },
}
