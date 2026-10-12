-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

hl.on("hyprland.start", function()
  local cursor_name = "phinger-cursor-dark"
  local cursor_size = 16

  ---@param cmd string
  local function uwsm_app(cmd)
    hl.exec_cmd(string.format("uwsm app -- %s", cmd))
  end

  uwsm_app("waybar")
  -- uwsm_app("nm-applet") # autostart
  uwsm_app("udiskie --tray")
  uwsm_app(string.format("hyprctl setcursor %s %s", cursor_name, cursor_size))
  uwsm_app("dunst --startup_notification")
  uwsm_app("wl-paste --type text --watch cliphist store")  -- Stores only text data
  uwsm_app("wl-paste --type image --watch cliphist store") -- Stores only image data

  hl.exec_cmd("awww-daemon & awww img ~/Pictures/wallpapers/wallpaper.jpg")
  -- hl.exec_cmd("syncthingtray qt-widgets-gui --single-instance --wait")
end)
