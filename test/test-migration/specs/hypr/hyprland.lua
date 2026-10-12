-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
  output   = "HDMI-A-1",
  mode     = "1280x1024@60.0Hz",
  position = "auto",
  scale    = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
Programs = {
  terminal    = "foot",
  fileManager = "caja",
  clipboard = "cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy",
}

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

require("configs.autostart")
require("configs.look_and_feel")
require("configs.misc")
require("configs.input")
require("configs.keybindings")
require("configs.rules")
