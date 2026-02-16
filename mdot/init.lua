---@class Link
---@field source PathString
---@field targets PathString[]
---@field backup boolean
---@field override boolean

---@class Package
---@field name string
---@field enabled fun(): boolean
---@field depends Package[]
---@field links LinkSpec[]
---@field excludes PathString[]

local log = require("mdot.log")
local tablex = require("pl.tablex")
local inspect = require("inspect")
local hybrid = require("hybrid")

local spec = require("mdot.spec")

---@param pkg? Package | {}
---@return Package
local function new_package(pkg)
   pkg = pkg or {}
   ---@type Package
   local defaults = {
      name = "",
      enabled = function() return true end,
      depends = {},
      links = {},
      excludes = {},
   }
   return tablex.merge(defaults, pkg, true)
end

---@param link_spec? LinkSpec | {}
---@return Link
local function link_from_link_spec(link_spec)
   link_spec = link_spec or {}

   ---@type Link
   local link = {
      source = "",
      targets = {},
      backup = link_spec.backup,
      override = link_spec.override,
   }

   ---@type PathString
   local source = ""
   ---@type TargetList
   local targets = {}

   local indexed = link_spec[1] and link_spec[2]
   local keyed = link_spec.source and link_spec.targets

   if indexed and keyed then
      -- TODO: throws an error
   elseif indexed then
      source = link_spec[1]
      targets = link_spec[2]
   elseif keyed then
      source = link_spec.source
      targets = link_spec.targets
   end

   ---@cast source PathString
   link.source = source
   if type(targets) == "string" then
      link.targets = { targets }
   elseif type(targets) == "table" then
      for _, target in ipairs(targets) do
         if type(target) == "string" then
            table.insert(link.targets, target)
         else
            -- Error
         end
      end
   end

   return link
end

---@param links Links
---@return LinkSpec[]
local function config_links_to_links(links)
   ---@type LinkSpec[]
   local links_specs = {}
   for key, value in pairs(links) do
      if type(key) == "integer" then
         -- TODO: use link_from_link_spec
      elseif type(key) == "string" then
         -- TODO: use link_from_link_spec
      else
         -- Error
      end
   end
   return links_specs
end

---@param name string
---@param config PackageSpec
---@return Package
local function package_config_to_package(name, config)
   local pkg = new_package()

   tablex.update(pkg, {
      name = name
   })

   local enabled = config.enabled
   if type(enabled) == "boolean" then
      pkg.enabled = function() return enabled end
   elseif type(enabled) == "function" then
      pkg.enabled = enabled
   else
      -- Error
   end

   -- TODO: handle pkg.depends

   local links = config.links
   if type(links) == "table" then
      pkg.links = config_links_to_links(links)
   else
      -- Error
   end

   return pkg
end

---@param configs PackageConfigs
---@return Package[]
local function package_configs_to_packages(configs)
   ---@type Package[]
   local out = {}

   for key, value in pairs(configs) do
      if type(key) == "integer" then
         if type(value) == "string" then
            table.insert(out, new_package({
               name = value,
            }))
         elseif type(value) == "table" then
         else
            -- Error
         end
      elseif type(key) == "string" then
         if type(value) == "table" then
            table.insert(out, package_config_to_package(key, value))
         else
            -- Error
         end
      end
   end

   return out
end

---@param configs PackageConfigs
local function deploy(configs)
   local _ = package_configs_to_packages(configs)
end

deploy({})
