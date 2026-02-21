---@alias mdot.Enabled fun(): boolean
---@alias mdot.DependOn string
---@alias mdot.Targets spec.PathString[]
---@alias mdot.Links table<spec.PathString, mdot.Targets>

---@class mdot.Package
---@field name string
---@field enabled mdot.Enabled
---@field depends string[] | mdot.Packages
---@field links mdot.Links
---@field excludes spec.PathString[]

---@alias mdot.Packages table<string, mdot.Package>

local log = require("mdot.log")
local tablex = require("pl.tablex")
local inspect = require("inspect")
local t = require("tableshape").types
local utils = require("mdot.utils")

local spec = require("mdot.spec")

local M = {}

M._DefaultEnable = function() return true end

---@param user_config spec.Packages
---@param memo? table<spec.Package, boolean> avoids recursion
---@return mdot.Packages
local function user_config_to_packages(user_config, memo)
   memo = memo or {}
   ---@type mdot.Packages
   local packages = {}
   for name, config in pairs(user_config) do
      if memo[config] then
         utils.throw_err(("recursive package config is not allowed: %s = %s"):format(name, config))
         goto continue
      end

      local enabled = config.enabled
      if enabled == nil then
         enabled = M._DefaultEnable
      end

      ---@type mdot.Enabled
      local pkg_enabled
      if type(enabled) == "function" then
         pkg_enabled = enabled
      else
         pkg_enabled = function() return enabled end
      end

      ---@type mdot.Package
      local pkg = {
         name = name,
         enabled = pkg_enabled,
         depends = {},
         links = {},
         excludes = {},
      }

      memo[config] = true
      packages[name] = pkg

      pkg.depends = user_config_to_packages(config.depends or {}, memo)
      pkg.links = tablex.map(utils.as_list, config.links or {})
      pkg.excludes = utils.as_list(config.excludes, {})

      ::continue::
   end
   return packages
end

---@param pkgs mdot.Packages
---@return mdot.Packages
local function flatten_packages(pkgs)
   ---@type mdot.Packages
   local flattened = {}

   ---@param p mdot.Package
   local function process(p)
      if flattened[p.name] then return end

      local dep_names = {}

      if type(p.depends) == "table" then
         for dep_name, dep_pkg in pairs(p.depends) do
            if type(dep_pkg) == "table" then
               process(dep_pkg)
               table.insert(dep_names, dep_name)
            else
               table.insert(dep_names, dep_pkg)
            end
         end
         p.depends = dep_names
      end

      flattened[p.name] = p
   end

   for _, pkg in pairs(pkgs) do
      process(pkg)
   end

   return flattened
end

---@param user_config spec.Package
---@return mdot.Packages
function M.normalize_user_config(user_config)
   local ok, err = spec.Packages(user_config)
   utils.throw(ok, err)

   local pkgs = user_config_to_packages(user_config)
   pkgs = flatten_packages(pkgs)
   return pkgs
end

---@param user_config spec.Packages
function M.deploy(user_config)
   local pkgs = M.normalize_user_config(user_config)
   print(inspect(pkgs))
end

M.normalize_user_config({
   git = {
      depends = {
         ["git-lfs"] = {
            depends = {
               neovim = {
                  depends = {
                     ["git"] = {}
                  }
               }
            }
         }
      },
      excludes = { "file" },
      links = {
         ["src"] = "dst",
         ["src_list"] = { "dst_list" },
      },
   },
})


return M
