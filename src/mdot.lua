---@alias Command string A command will be executed using "bash -c <command>"
---@alias Hook Command | fun() | (Command | fun())[]

---@alias OSPackage string | table<string, string>
---@alias Path string The directory or file path
---@alias Targets Path | Path[]  -- either a single string or an array of strings

---@class LinkEntry
---@field source Path
---@field targets Targets
---@field overwrite boolean
---@field backup boolean

---@alias LinkTableEntry LinkEntry | { [Path]: Targets }
---@alias Links LinkTableEntry[]

---@class (exact) PackageSpec
---@field enabled? boolean | fun(): boolean Defaults to true
---@field depends? Packages
---@field name? string
---@field app_name? string
---@field package_name? OSPackage
---@field default_target? Path Defaults to XDG_HOME_CONFIG or ~/.config/
---@field links? Links
---@field exclude? Targets
---@field templates? Targets
-- Still unsure about hooks
---@field on_install? Hook Will be executed after the package and dependencies are installed.
---@field on_deploy? Hook Will be executed after the files has been linked.

---@alias PackageUnion string | PackageSpec | {string: PackageSpec}

---@alias Packages PackageUnion[]

local PlatformDirs = require("platformdirs").PlatformDirs
local inspect = require("inspect")
local tablex = require("pl.tablex")
local dir = require("pl.dir")
local pl_path = require("pl.path")
local pl_types = require("pl.types")
local M = {}

---@param name string
---@param pkg PackageSpec
function M.pkg_set_defaults(name, pkg)
   pkg.enabled = pkg.enabled or true
   pkg.name = pkg.name or name
   pkg.app_name = pkg.app_name or name
   pkg.default_target = pkg.default_target or M.ctx.platform_dirs:user_config_dir()
   pkg.depends = pkg.depends or {}
   pkg.links = pkg.links or {}
   pkg.exclude = pkg.exclude or {}
end

---@param targets Targets
---@return Path[] | nil
function M.normalize_targets(targets)
   if type(targets) == "string" then
      return { targets }
   elseif type(targets) == "table" then
      return targets
   end
   assert(type(targets) ~= nil, "Unhandled 'targets' type: ("..type(targets)..") = "..inspect(targets))
   return nil
end

---@param name string
---@param p string | PackageSpec
---@return PackageSpec
function M.pkg_new_spec(name, p)
   local ret = tablex.deepcopy(p)
   if type(ret) == "string" then
      ret = {
         name = name
      }
   end
  -- M.pkg_set_defaults(name, ret)
   ret.exclude = M.normalize_targets(ret.exclude)
   ret.templates = M.normalize_targets(ret.templates)

   return ret
end

---@param name string | integer
---@param spec string | PackageSpec
---@return string
local function get_name(name, spec)
   if type(name) == "string" and #name > 0 then
      if not tonumber(name) then
         return name
      end
   end

   if type(spec) == "string" then
      return spec
   end

   if spec.package_name then
      local pkg = spec.package_name
      if type(pkg) == "string" then
         return pkg
      end

      if #tablex.values(spec) > 0 then
         return tablex.values(spec)[1]
      end
   end

   return spec.app_name
       or spec.name
       or error("Package spec must define package_name or app_name or name\n" .. inspect(spec))
end

--- Recursively normalize packages and their dependencies
---@param packages Packages[]
---@return table<string, PackageSpec>
function M.normalize_packages(packages)
   local normalized = {}

   for name, pkg in pairs(packages) do
      local pkg_name = get_name(name, pkg)
      local spec = M.pkg_new_spec(pkg_name, pkg)

      -- Recursively normalize dependencies
      if spec.depends and type(spec.depends) == "table" then
         spec.depends = M.normalize_packages(spec.depends)
      end

      normalized[pkg_name] = spec
   end

   return normalized
end

---@param packages table<string, PackageSpec>
---@return table<string, PackageSpec>
function M.fix_dependencies(packages)
   local function is_map(t)
      if type(t) ~= "table" then return false end
      for k, _ in pairs(t) do
         if type(k) == "string" then return true end
      end
      return false
   end

   ---@param top_pkg PackageSpec | nil
   ---@param dep_pkg PackageSpec
   ---@return PackageSpec
   local function handle_conflict(top_pkg, dep_pkg)
      -- TODO: will handle confict options, for now, use default.
      return top_pkg or dep_pkg
   end

   local function process(_, spec)
      if type(spec) ~= "table" then return end
      if type(spec.depends) ~= "table" then return end

      if is_map(spec.depends) then
         local new_list = {}
         for dep_name, dep_spec in pairs(spec.depends) do
            table.insert(new_list, dep_name)

            if type(dep_spec) == "table" then
               local lifted = handle_conflict(packages[dep_name], tablex.deepcopy(dep_spec))
               packages[dep_name] = lifted
               process(dep_name, lifted)
            end
         end

         if #new_list > 0 then
            table.sort(new_list)
            spec.depends = new_list
         else
            spec.depends = nil
         end
      end
   end

   for name, spec in pairs(packages) do
      process(name, spec)
   end

   return packages
end

---@param packages Packages
---@return Packages
function M.init_links(packages)
   for name, pkg in pairs(packages) do
      assert(pkg.links and type(pkg.links) == "table", inspect(pkg.links))

      local path = pl_path.join(M.ctx.app_config_path, pkg.app_name)
      local target_path = pl_path.join(M.ctx.config_path, pkg.app_name)
      local files = dir.getallfiles(path)

      for _, file in pairs(files) do
         local relpath = pl_path.relpath(file, path)
         ---@type Targets
         local targets = pkg.links[relpath] or {}

         if type(targets) == "string" then
            targets = { targets }
         end

         targets = tablex.map(function(p)
            return M.ctx.platform_dirs:expand_user(p)
         end, targets)

         local dst = pl_path.join(target_path, relpath)
         local matched = tablex.find_if(pkg.exclude, function(exclude)
            return dir.fnmatch(relpath, exclude)
         end) ~= nil

         if not matched then
            table.insert(targets, dst)
         end

         pkg.links[relpath] = nil
         pkg.links[pl_path.join(target_path, relpath)] = targets
      end
   end
   return packages
end

---@param pkgs Packages[]
function M.deploy(pkgs)
   local all_packages = M.normalize_packages(pkgs)
   all_packages = M.fix_dependencies(all_packages)
   for name, spec in pairs(all_packages) do
      assert(type(name) == "string")
      ---@cast spec PackageSpec
      M.pkg_set_defaults(tostring(name), spec)
   end
   all_packages = M.init_links(all_packages)
   print("Normalized packages: " .. inspect(all_packages))
end

function M.init()
   local appname = "mdot"

   local function get_app_name()
      local name = os.getenv("MDOT_APPNAME")
      return (name and #name > 0) and name or appname
   end

   ---@return string
   local function get_user_config_dir()
      local path = M.ctx.platform_dirs:user_config_dir()

      return path .. "/" .. M.ctx.app_name
   end

   M.ctx = {
      app_name = get_app_name(),
      app_dirs = PlatformDirs {
         appname = get_app_name(),
      },
      platform_dirs = PlatformDirs {},
   }

   -- Directories
   tablex.update(M.ctx, {
      app_config_path = get_user_config_dir(),
      config_path = M.ctx.platform_dirs:user_config_dir(),
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

-- M.init()
-- M.print_ctx()
-- M.deploy(require("mdot"))
return M
