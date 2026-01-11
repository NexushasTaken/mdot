local mdot = require("src.mdot")

return function()
   mdot.init_global_pkgs()

   lu.assertEquals(mdot.pkgs_normalize({
      neovim = {
         depends = { pkgs.ripgrep },
      }
   }), {
      neovim = {
         depends = { "ripgrep" },
      },
      ripgrep = {},
   })

   lu.assertEquals(mdot.pkgs_normalize({
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
      neovim = {},
   })

   lu.assertEquals(mdot.pkgs_normalize({
      hyprland = {
         depends = {
            "neovim"
         },
      },
      pkgs.neovim,
   }), {
      hyprland = {
         depends = {
            "neovim"
         },
      },
      neovim = {},
   })

   lu.assertEquals(mdot.pkgs_normalize({
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

   lu.assertEquals(mdot.pkgs_normalize({
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

   lu.assertEquals(mdot.pkgs_normalize({
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

   lu.assertEquals(mdot.pkgs_normalize({
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

   lu.assertEquals(mdot.pkgs_normalize({
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
