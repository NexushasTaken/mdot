---@diagnostic disable: lowercase-global

function testPackageName()
   local p

   p = mdot.normalize_user_config({
      a = {}
   })
   lu.assertEquals(p["a"].name, "a")
end

function testPackageEnabled()
   local p

   p = mdot.normalize_user_config({
      a = {}
   })
   lu.assertEquals(p["a"].enabled(), true)

   p = mdot.normalize_user_config({
      a = {
         enabled = true
      }
   })
   lu.assertEquals(p["a"].enabled(), true)

   p = mdot.normalize_user_config({
      a = {
         enabled = false
      }
   })
   lu.assertEquals(p["a"].enabled(), false)

   p = mdot.normalize_user_config({
      a = {
         enabled = function() return true end,
      }
   })
   lu.assertEquals(p["a"].enabled(), true)

   p = mdot.normalize_user_config({
      a = {
         enabled = function() return false end,
      }
   })
   lu.assertEquals(p["a"].enabled(), false)
end

function testPackageExcludes()
   local p

   p = mdot.normalize_user_config({
      a = {}
   })
   lu.assertEquals(p["a"].excludes, {})

   p = mdot.normalize_user_config({
      a = {
         excludes = "file"
      }
   })
   lu.assertEquals(p["a"].excludes, { "file" })

   p = mdot.normalize_user_config({
      a = {
         excludes = { "file" }
      }
   })
   lu.assertEquals(p["a"].excludes, { "file" })
end

function testPackageLinks()
   local p

   p = mdot.normalize_user_config({
      a = {}
   })
   lu.assertEquals(p["a"].links, {})

   p = mdot.normalize_user_config({
      a = {
         links = {}
      }
   })
   lu.assertEquals(p["a"].links, {})

   p = mdot.normalize_user_config({
      a = {
         links = {
            ["src"] = "dst"
         }
      }
   })
   lu.assertEquals(p["a"].links, { ["src"] = { "dst" } })

   p = mdot.normalize_user_config({
      a = {
         links = {
            ["src_list"] = { "dst" }
         }
      }
   })
   lu.assertEquals(p["a"].links, { ["src_list"] = { "dst" } })
end
