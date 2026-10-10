--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

local center_position = { "(monitor_w - window_w) / 2", "(monitor_h - window_h) / 2" }

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
  -- Ignore maximize requests from all apps. You'll probably like this.
  name           = "suppress-maximize-events",
  match          = { class = ".*" },

  suppress_event = "maximize",
})

hl.window_rule({
  -- Fix some dragging issues with XWayland
  name     = "fix-xwayland-drags",
  match    = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },

  no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
  name  = "move-hyprland-run",
  match = { class = "hyprland-run" },

  move  = "20 monitor_h-120",
  float = true,
})

hl.window_rule({
  name = "kitty",
  match = {
    class = "^kitty$",
    title = "^kitty$"
  },
})

hl.window_rule({
  name = "pavucontrol",
  match = {
    class = "^org.pulseaudio.pavucontrol",
  },
  float = true,
})

hl.window_rule({
  name = "terminals-workspace",
  match = {
    class = "^(Alacritty|foot)$",
  },
  workspace = 1,
})

hl.window_rule({
  name = "browser-workspace",
  match = {
    class = "^(firefox)$",
  },
  workspace = 2,
})

hl.window_rule({
  name = "discord-workspace",
  match = {
    class = "^(discord)$",
  },
  workspace = 8,
})

hl.window_rule({
  name = "genshin-impact",
  match = {
    class = "^(steam_proton|gamescope|gamemoderun)*",
    title = "^Genshin Impact*",
  },
  move = center_position,
  -- size = { 1280, 720 },
  workspace = 9,
  float = true,
  content = "game",
})

hl.window_rule({
  name = "minecraft",
  match = {
    class = "^Minecraft.*",
    title = "^Minecraft.*",
  },
  size = { 1280, 720 },
  workspace = 9,
  float = true,
  content = "game",
})

hl.window_rule({
  name = "freesmlauncher",
  match = {
    class = "^org.freesmlauncher.FreesmLauncher$",
  },
  workspace = 9,
  content = "game",
})

hl.window_rule({
  name = "aottg2",
  match = {
    class = "^Aottg2Linux.*$",
    title = "^Aottg2$",
  },
  size = { 1280, 720 },
  workspace = 9,
  float = true,
  content = "game",
})

hl.window_rule({
  name = "terraria",
  match = {
    class = "^Terraria.*$",
    title = "^Terraria.*$",
  },
  size = { 1280, 720 },
  workspace = 9,
  float = true,
  content = "game",
})

hl.window_rule({
  name = "osu-lazer",
  match = {
    class = "^osu!$",
    title = "^osu!$",
  },
  workspace = 9,
  float = true,
  fullscreen = true,
  content = "game",
})

hl.window_rule({
  name = "osu-stable",
  match = {
    class = "^osu!.exe$",
  },
  workspace = 9,
  float = true,
  fullscreen = true,
  content = "game",
})

hl.window_rule({
  name = "waydroid",
  match = {
    class = "^Waydroid$",
    title = "^Waydroid$",
  },
  workspace = 9,
  float = true,
  content = "game",
})

hl.window_rule({
  name = "obsidian",
  match = {
    class = "^obsidian$",
  },
  workspace = 4,
})

hl.window_rule({
  name = "logseq",
  match = {
    class = "^Logseq$",
  },
  workspace = 5,
})

hl.window_rule({
  name = "visual-studio-code",
  match = {
    class = "^Code$",
  },
  workspace = 6,
})

hl.window_rule({
  name = "code",
  match = {
    class = "^Code$",
  },
  workspace = 10,
})

hl.window_rule({
  name = "obs",
  match = {
    class = "^com.obsproject.Studio$",
  },
  workspace = 10,
})

hl.window_rule({
  name = "obs",
  match = {
    class = "^com.obsproject.Studio$",
  },
  float = true,
  size = { 600, 500 },
  move = { "(monitor_w-window_w)", 0 },
})
