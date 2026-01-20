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

---@param p PackageItemSpec
---@return PackageSchema
function PackageProps:new(p)
   p = tablex.deepcopy(p)

   -- "name" -> { [1] = "name" }
   if type(p) == "string" then
      p = { [1] = p }
   end

   local val, err = schema.is_package_item(p)
   if not val then
      print("new: " .. inspect(p) .. " " .. inspect(err))
      os.exit()
   end

   -- { [1] = "name"} -> { name = "name" }
   if p[1] then
      local name = p[1]
      p[1] = nil
      p.name = name
   end

   setmetatable(p, self)
   self.__index = self

   self:_set_defaults()
   p.excludes = self.normalize_targets(p.excludes)
   p.templates = self.normalize_targets(p.templates)
   return p
end

---@param targets TargetList
---@return TargetList
function PackageProps.normalize_targets(targets)
   if type(targets) == "string" then
      return { targets }
   elseif type(targets) == "table" then
      return targets
   end
end

function PackageProps:_set_defaults()
   if self.enabled == nil then
      self.enabled = true
   end
   self.depends = self.depends or {}
   --self.package_name = self.package_name or name
   self.default_target = self.default_target or M.ctx.platform_dirs:user_config_dir()
   self.links = self.links or {}
   self.excludes = self.excludes or {}
   self.templates = self.templates or {}
end

--- Recursively normalize packages and their dependencies
---@param packages PackageList
---@return PackageSchema[]
function M.normalize_packages(packages)
   local normalized = {}

   for _, pkg in pairs(packages) do
      local spec = PackageProps:new(pkg)

      -- Recursively normalize dependencies
      if spec.depends and type(spec.depends) == "table" then
         spec.depends = M.normalize_packages(spec.depends)
      end

      normalized[spec.name] = spec
   end

   return normalized
end

---@param packages PackageSchema[]
---@return PackageList
function M.fix_dependencies(packages)
   local function is_map(t)
      if type(t) ~= "table" then return false end
      for k, _ in pairs(t) do
         if type(k) == "string" then return true end
      end
      return false
   end

   ---@param pkg_name string
   ---@return number, PackageList | nil
   local function get_top_pkg(pkg_name)
      for idx, spec in ipairs(packages) do
         if spec.name == pkg_name then
            return idx, spec
         end
      end
      return 0, nil
   end
   ---@param top_pkg PackageList | nil
   ---@param dep_pkg PackageList
   ---@return PackageList
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
               local idx, top_pkg = get_top_pkg(dep_name)
               local lifted = handle_conflict(top_pkg, tablex.deepcopy(dep_spec))
               packages[idx] = lifted
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

---@param packages PackageList
---@return PackageList
local function init_links(packages)
   for _, pkg in pairs(packages) do
      assert(pkg.links and type(pkg.links) == "table", inspect(pkg.links))

      local path = pl_path.join(M.ctx.app_config_path, pkg.name)
      local target_path = pl_path.join(M.ctx.config_path, pkg.name)
      local files = dir.getallfiles(path)

      for _, file in pairs(files) do
         local relpath = pl_path.relpath(file, path)
         ---@type TargetList
         local targets = pkg.links[relpath] or {}

         if type(targets) == "string" then
            targets = { targets }
         end

         targets = tablex.map(function(p)
            return M.ctx.platform_dirs:expand_user(p)
         end, targets)

         local dst = pl_path.join(target_path, relpath)
         local matched = tablex.find_if(pkg.excludes, function(excludes)
            return dir.fnmatch(relpath, excludes)
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

---@param pkgs PackageList
function M.deploy(pkgs)
   local all_packages = M.normalize_packages(pkgs)
   all_packages = M.fix_dependencies(all_packages)
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

      return path .. "/" .. M.ctx.name
   end

   M.ctx = {
      name = get_app_name(),
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
   if _G.__test then
      return
   end
   _G.__test = true

   M.init()
   local ctx = tablex.deepcopy(M.ctx)
   ctx.app_dirs = nil
   ctx.platform_dirs = nil
   print("ctx: " .. inspect(ctx))
   local pkgs = require("main")
   print("pkgs: " .. inspect(pkgs))
   M.deploy(pkgs)
end

-- test()

return M
