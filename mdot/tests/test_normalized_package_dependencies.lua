local mdot = require("mdot")
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

      -- multiple siblings lifted at once
   lu.assertEquals(normalize({
      app = {
         depends = {
            foo = {},
            bar = { enabled = true },
         }
      }
   }), {
      app = { depends = { "bar", "foo" } },
      foo = {},
      bar = { enabled = true },
   })

   -- deeply nested chain
   lu.assertEquals(normalize({
      top = {
         depends = {
            mid = {
               depends = {
                  leaf = { version = "1.0" }
               }
            }
         }
      }
   }), {
      top = { depends = { "mid" } },
      mid = { depends = { "leaf" } },
      leaf = { version = "1.0" },
   })

   -- conflict: nested spec vs top-level spec
   lu.assertEquals(normalize({
      app = {
         depends = {
            lib = { foo = "nested" }
         }
      },
      lib = { foo = "top" }
   }), {
      app = { depends = { "lib" } },
      lib = { foo = "top" },  -- conflict resolution: top wins (default policy)
   })

   -- multiple levels with mixed styles
   lu.assertEquals(normalize({
      root = {
         depends = {
            child1 = {
               depends = {
                  grandchild = {}
               }
            },
            child2 = {}
         }
      }
   }), {
      root = { depends = { "child1", "child2" } },
      child1 = { depends = { "grandchild" } },
      child2 = {},
      grandchild = {},
   })

   -- package with no depends untouched
   lu.assertEquals(normalize({
      solo = { enabled = true }
   }), {
      solo = { enabled = true }
   })

   -- nested spec with both exclude and templates
   lu.assertEquals(normalize({
      app = {
         depends = {
            dep = {
               exclude = "*",
               templates = "foo"
            }
         }
      }
   }), {
      app = { depends = { "dep" } },
      dep = {
         exclude = { "*" },
         templates = { "foo" }
      }
   })
end
