local mdot = require("src.mdot")
local inspect = require("inspect")

return function()
   mdot.init()

   local function normalize(tbl)
      local t = mdot.fix_dependencies(mdot.normalize_packages(tbl))
      return t
   end

   lu.assertEquals(normalize({
      neovim = {
         depends = { pkgs.ripgrep },
      }
   }), {
      neovim = {
         depends = { "ripgrep" },
      },
      ripgrep = {
         name = "ripgrep",
      },
   })

   lu.assertEquals(normalize({
      hyprland = {
         depends = {
            "neovim"
         },
      },
      "neovim",
   }), {
      hyprland = {
         depends = {
            "neovim"
         },
      },
      neovim = {
         name = "neovim"
      },
   })

   lu.assertEquals(normalize({
      hyprland = {
         depends = {
            "neovim"
         },
      },
      pkgs.neovim,
   }), {
      hyprland = {
         depends = {
            "neovim",
         },
      },
      neovim = {
         name = "neovim",
      },
   })

   lu.assertEquals(normalize({
      hyprland = {
         depends = {
            waybar = {}
         },
      },
   }), {
      hyprland = {
         depends = {
            "waybar"
         },
      },
      waybar = {},
   })

   lu.assertEquals(normalize({
      hyprland = {
         depends = {
            waybar = {}
         },
      },
      waybar = {
         exclude = "*",
      }
   }), {
      hyprland = {
         depends = {
            "waybar"
         },
      },
      waybar = {
         exclude = { "*" },
      },
   })

   lu.assertEquals(normalize({
      hyprland = {
         depends = {
            waybar = {
               exclude = "*",
            }
         },
      },
      waybar = {}
   }), {
      hyprland = {
         depends = {
            "waybar"
         },
      },
      waybar = {},
   })

   lu.assertEquals(normalize({
      hyprland = {
         depends = {
            waybar = {
               exclude = "*",
            }
         },
      },
   }), {
      hyprland = {
         depends = {
            "waybar"
         },
      },
      waybar = {
         exclude = { "*" },
      },
   })

   lu.assertEquals(normalize({
      hyprland = {
         depends = {
            waybar = {
               exclude = "*",
               depends = {
                  git = {
                     enabled = true,
                  }
               }
            }
         },
      },
   }), {
      hyprland = {
         depends = {
            "waybar"
         },
      },
      waybar = {
         exclude = { "*" },
         depends = { "git" }
      },
      git = {
         enabled = true,
      },
   })
end
