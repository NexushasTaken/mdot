---@diagnostic disable: lowercase-global
local tablex = require("pl.tablex")

function testPackageName()
   local p

   local enabled = mdot._DefaultEnable
   local default = {
      enabled = enabled,
      excludes = {},
      links = {},
   }

   p = mdot.normalize_user_config({
      a = {
         depends = {
            b = {}
         }
      }
   })
   lu.assertEquals(p, {
      a = {
         depends = {
            "b",
         },
         enabled = enabled,
         excludes = {},
         links = {},
         name = "a",
      },
      b = {
         depends = {},
         enabled = enabled,
         excludes = {},
         links = {},
         name = "b",
      },
   })

   p = mdot.normalize_user_config({
      a = {
         depends = {
            b = {
               depends = {
                  c = {}
               }
            }
         }
      }
   })
   lu.assertEquals(p, {
      a = {
         depends = {
            "b",
         },
         enabled = enabled,
         excludes = {},
         links = {},
         name = "a",
      },
      b = {
         depends = { "c" },
         enabled = enabled,
         excludes = {},
         links = {},
         name = "b",
      },
      c = {
         depends = {},
         enabled = enabled,
         excludes = {},
         links = {},
         name = "c",
      },
   })

   -- p = mdot.normalize_user_config({
   --    a = {
   --       depends = {
   --          b = {
   --             depends = {
   --             }
   --          }
   --       }
   --    },
   --    c = {}
   -- })
   -- lu.assertEquals(p, {
   --    a = {
   --       depends = {
   --          "b",
   --       },
   --       enabled = enabled,
   --       excludes = {},
   --       links = {},
   --       name = "a",
   --    },
   --    b = {
   --       depends = { "c" },
   --       enabled = enabled,
   --       excludes = {},
   --       links = {},
   --       name = "b",
   --    },
   --    c = {
   --       depends = {},
   --       enabled = enabled,
   --       excludes = {},
   --       links = {},
   --       name = "c",
   --    },
   -- })
end
