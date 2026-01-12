local mdot = require("src.mdot")

return function()
   lu.assertEquals(mdot.normalize_packages({}), {})
   lu.assertEquals(mdot.normalize_packages({ "neovim" }), {
      neovim = {
         name = "neovim",
      },
   })
   lu.assertEquals(mdot.normalize_packages({
      { name = "neovim", }
   }), {
      neovim = { name = "neovim", },
   })
   lu.assertEquals(mdot.normalize_packages({
      {
         name = "neovim",
         package_name = "nvim",
      }
   }), {
      nvim = {
         name = "neovim",
         package_name = "nvim",
      },
   })

   mdot.init_global_pkgs()
   lu.assertEquals(mdot.normalize_packages({
      pkgs.neovim
   }), {
      neovim = {
         name = "neovim",
      },
   })
   lu.assertEquals(mdot.normalize_packages({
      pkgs.neovim,
      {
         name = "neovim",
         exclude = "*",
      }
   }), {
      neovim = {
         name = "neovim",
         exclude = { "*" },
      },
   })
   lu.assertEquals(mdot.normalize_packages({
      pkgs.neovim,
      neovim = { exclude = { "*" }, }
   }), {
      neovim = { exclude = { "*" }, },
   })
end
