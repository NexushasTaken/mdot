local mdot = require("src.mdot")

return function()
   lu.assertEquals(mdot.pkgs_normalize({}), {})
   lu.assertEquals(mdot.pkgs_normalize({ "neovim" }), {
      neovim = {},
   })
   lu.assertEquals(mdot.pkgs_normalize({
      { name = "neovim", }
   }), {
      neovim = { name = "neovim", },
   })
   lu.assertEquals(mdot.pkgs_normalize({
      {
         name = "neovim",
         package_name = "nvim",
      }
   }), {
      neovim = {
         name = "neovim",
         package_name = "nvim",
      },
   })

   mdot.init_global_pkgs()
   lu.assertEquals(mdot.pkgs_normalize({
      pkgs.neovim
   }), {
      neovim = {},
   })
   lu.assertEquals(mdot.pkgs_normalize({
      pkgs.neovim,
      {
         name = "neovim",
         exclude = "*",
      }
   }), {
      neovim = {
         name = "neovim",
         exclude = "*",
      },
   })
   lu.assertEquals(mdot.pkgs_normalize({
      pkgs.neovim,
      neovim = { exclude = "*", }
   }), {
      neovim = { exclude = "*", },
   })
end
