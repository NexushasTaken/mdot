---@enum DistroID
local distro_id = {
   "arch",
   "debian",
}

---@alias Path string The directory or file path
---@alias Command string A command will be executed using "bash -c <command>"
---@alias Hook Command | fun() | (Command | fun())[]

---@class LinkSpec
---@field source Path Path relative to ~/.config/mdot/pkgs/
---@field target Path Path relative to package.default_target
---@field overwrite? boolean
---@field backup? boolean
---@alias Link LinkSpec | table<string, string>

---@class (exact) PackageSpec
---@field enabled? boolean | fun(): boolean Defaults to true
---@field name? string
---@field default_target? Path Defaults to XDG_HOME_CONFIG or ~/.config/
---@field links? Link[]
---@field package_name? table<DistroID, string> | string
---@field exclude? Path | Path[]
---@field templates? Path | Path[]
---@field depends? Packages
-- Still unsure about hooks
---@field on_install? Hook Will be executed after the package and dependencies are installed.
---@field on_deploy? Hook Will be executed after the files has been linked.

---@alias PackageUnion string | PackageSpec | {string: PackageSpec}

---@alias Packages PackageUnion[]

local PlatformDirs = require("platformdirs").PlatformDirs
local inspect = require("inspect")
local tablex = require("pl.tablex")
local dir = require("pl.dir")
local M = {}

---@param pkgs PackageSpec[]
function M.pkgs_normalize_dependencies(pkgs)
   for pkg_name, spec in pairs(pkgs) do
      if not spec.depends then
         goto continue
      end

      local depends = {}
      for k, v in pairs(spec.depends) do
         local key, value = M.pkg_normalize(v, k)
         table.insert(depends, key)
         if not pkgs[key] then
            pkgs[key] = value
         end
      end

      spec.depends = depends

      ::continue::
   end
end

---@param pkg PackageUnion
---@param idx number|string
function M.pkg_normalize(pkg, idx)
   ---@type string
   local key = nil
   ---@type PackageSpec
   local val = nil

   if type(idx) == "number" then
      if type(pkg) == "string" then
         key = pkg
         val = {}
      elseif type(pkg) == "table" then
         key = pkg.name
         val = pkg
      end
   elseif type(idx) == "string" then
      if type(pkg) == "table" then
         key = idx
         val = pkg
      end
   end

   -- print()
   -- print(type(idx) .. " " .. tostring(idx), "=", type(pkg) .. " " .. tostring(pkg))

   return key, val
end

---@param pkgs Packages
---@return PackageSpec
function M.pkgs_normalize(pkgs)
   local norm_pkgs = {}
   for k, v in pairs(pkgs) do
      local key, val = M.pkg_normalize(v, k)

      if key ~= nil and val ~= nil then
         norm_pkgs[key] = val
      end
   end

   M.pkgs_normalize_dependencies(norm_pkgs)
   return norm_pkgs
end

---@param pkg PackageSpec
function M.pkg_set_defaults(name, pkg)
   pkg.enabled = pkg.enabled or true
   pkg.name = pkg.name or name
   pkg.package_name = pkg.package_name or name
   pkg.default_target = pkg.default_target or M.ctx.platform_dirs:user_config_dir()
   pkg.depends = pkg.depends or {}
end

---@param pkgs Packages[]
function M.deploy(pkgs)
   pkgs = M.pkgs_normalize(pkgs)
   for name, pkg in pairs(pkgs) do
      M.pkg_set_defaults(name, pkg)
   end
   print("pkgs: " .. inspect(pkgs))
end

function M.init()
   local appname = "mdot"

   local function get_app_name()
      local name = os.getenv("MDOT_APPNAME")
      return (name and #name > 0) and name or appname
   end

   local function get_user_config_dir()
      local path = os.getenv("MDOT_CONFIG_PATH")
      if not path then
         path = M.ctx.platform_dirs:user_config_dir()
      end

      return path .. "/" .. M.ctx.app_name
   end

   M.ctx = {
      app_name = get_app_name(),
      app_dirs = PlatformDirs {
         appname = get_app_name(),
      },
      platform_dirs = PlatformDirs {},
   }

   tablex.update(M.ctx, {
      app_config_path = get_user_config_dir(),
   })

   M.init_config_searcher()
   M.init_global_pkgs()
end

function M.init_config_searcher()
   table.insert(package.searchers, 1, M.load_config)
end

function M.init_global_pkgs()
   local function get_package(tbl, pkgname)
      local pkgs = rawget(tbl, "__resolve_pkgs") -- bypass metatable
      if not pkgs then
         pkgs = {}
         rawset(tbl, "__resolve_pkgs", pkgs)
      end
      table.insert(pkgs, pkgname)
      return pkgname -- whatever table you want to return
   end

   _G.pkgs = setmetatable({}, {
      __index = get_package
   })
end

---@param modname string
function M.load_config(modname)
   local rel = modname:gsub("%.", "/")
   local p1 = M.ctx.app_config_path .. "/" .. rel .. ".lua"
   local p2 = M.ctx.app_config_path .. "/" .. rel .. "/init.lua"

   for _, p in ipairs({ p1, p2 }) do
      local file = io.open(p, "r")
      if file then
         file:close()
         return assert(loadfile(p))
      end
   end
end

function M.print_ctx()
   local ctx = tablex.deepcopy(M.ctx)
   ctx.app_dirs = nil
   ctx.platform_dirs = nil
   print("ctx: " .. inspect(ctx))
end

M.init()
M.print_ctx()
M.deploy(require("mdot"))
return M
