local mdot = require("src.mdot")

return function()
   mdot.init_global_pkgs()

   lu.assertEquals(mdot.normalize_packages({
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

   lu.assertEquals(mdot.normalize_packages({
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

   lu.assertEquals(mdot.normalize_packages({
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

   lu.assertEquals(mdot.normalize_packages({
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

   lu.assertEquals(mdot.normalize_packages({
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

   lu.assertEquals(mdot.normalize_packages({
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

   lu.assertEquals(mdot.normalize_packages({
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

   lu.assertEquals(mdot.normalize_packages({
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
