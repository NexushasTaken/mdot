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

---@class (exact) PackageProps
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

---@alias PackageUnion string | PackageProps | {string: PackageProps}

---@alias Packages PackageUnion[]

local PlatformDirs = require("platformdirs").PlatformDirs
local inspect = require("inspect")
local tablex = require("pl.tablex")
local dir = require("pl.dir")
local pl_path = require("pl.path")
local schema = require("mdot.schema")
local M = {}

function M.assert_unhandled_type(name, value)
   assert(false, string.format("Unhandled '%s' type: %s = %s", name, type(self.targets), inspect(value)))
end

PackageProps = {}

-- TODO: Rename PackageProps -> PackageProps
---@param p PackageProps | string
---@returm PackageProps
function PackageProps:new(p)
   --local val, err = schema.is_package2(p)
   --print(inspect(val), inspect(err))
   if not val then print(inspect(err)) end

   p = tablex.deepcopy(p)
   if type(p) == "string" then
      p = { name = p }
   end
   setmetatable(p, self)
   self.__index = self

   self._set_defaults(name)
   p.exclude = M.normalize_targets(p.exclude)
   p.templates = M.normalize_targets(p.templates)
   return p
end

function PackageProps:normalize_targets()
   if type(self.targets) == "string" then
      self.targets = { self.targets }
   elseif type(self.targets) == "table" then
      self.targets = self.targets
   end
end

---@param name string
function PackageProps:_set_defaults(name)
   if self.enabled == nil then
      self.enabled = true
   end
   self.depends = self.depends or {}
   self.name = self.name or name
   self.app_name = self.app_name or name
   --self.package_name = self.package_name or name
   self.default_target = self.default_target or M.ctx.platform_dirs:user_config_dir()
   self.links = self.links or {}
   self.exclude = self.exclude or {}
   self.templates = self.templates or {}
end

---@return string
function PackageProps:get_name()
   if type(self.name) == "string" and #self.name > 0 then
      if not tonumber(self.name) then
         return self.name
      end
   end

   if self.package_name then
      local pkg = self.package_name
      if type(pkg) == "string" then
         return pkg
      end

      if #tablex.values(pkg) > 0 then
         return tablex.values(pkg)[1]
      end
   end

   return self.app_name
       or self.name
       or error("The field package_name or app_name or name must exist on PackageProps\n" .. inspect(self))
end

--- Recursively normalize packages and their dependencies
---@param packages Packages
---@return table<string, PackageProps>
function M.normalize_packages(packages)
   local normalized = {}

   for name, pkg in pairs(packages) do
      local spec = PackageProps:new(pkg_name, pkg)
      local pkg_name = spec:get_name()

      -- Recursively normalize dependencies
      if spec.depends and type(spec.depends) == "table" then
         spec.depends = M.normalize_packages(spec.depends)
      end

      normalized[pkg_name] = spec
   end

   return normalized
end

---@param packages table<string, PackageProps>
---@return table<string, PackageProps>
function M.fix_dependencies(packages)
   local function is_map(t)
      if type(t) ~= "table" then return false end
      for k, _ in pairs(t) do
         if type(k) == "string" then return true end
      end
      return false
   end

   ---@param top_pkg PackageProps | nil
   ---@param dep_pkg PackageProps
   ---@return PackageProps
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
local function init_links(packages)
   for _, pkg in pairs(packages) do
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
      ---@cast spec PackageProps
      pkg_set_defaults(tostring(name), spec)
   end
   all_packages = init_links(all_packages)
   print("Normalized packages: " .. inspect(all_packages))
end

---@param modname string
local function load_config(modname)
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

local function init_config_searcher()
   table.insert(package.searchers, 1, load_config)
end

local function init_global_pkgs()
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

   init_config_searcher()
   init_global_pkgs()
end

local function test()
   M.init()
   local ctx = tablex.deepcopy(M.ctx)
   ctx.app_dirs = nil
   ctx.platform_dirs = nil
   print("ctx: " .. inspect(ctx))
   M.deploy(require("mdot"))
end

--test()

return M
