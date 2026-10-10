---------------
---- INPUT ----
---------------

hl.config({
  input = {
    kb_layout     = "us",
    kb_variant    = "",
    kb_model      = "",
    kb_options    = "",
    kb_rules      = "",

    repeat_rate   = 20,
    repeat_delay  = 300,

    follow_mouse  = 1,

    sensitivity   = 0, -- -1.0 - 1.0, 0 means no modification.
    accel_profile = "flat",

    touchpad      = {
      natural_scroll = false,
    },
    -- tablet = {
    --   relative_input = false,
    --   left_handed = true,
    -- },
    -- tablettool = {
    --   pressure_range_min = 0.24425989999999997,
    -- },
  },
})

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
-- hl.device({
--   name        = "epic-mouse-v1",
--   sensitivity = -0.5,
-- })
