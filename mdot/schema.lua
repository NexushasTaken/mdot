---@alias Command string
---@alias HookAction Command | fun() | (Command | fun())[]

---@alias OSPackageSpec string | table<string, string>
---@alias PathString string
---@alias TargetList PathString | PathString[]

---@class LinkObject
---@field source? PathString
---@field targets? TargetList
---@field override? boolean
---@field backup? boolean

---@alias LinkEntrySpec LinkObject | table<PathString, TargetList>
---@alias LinksArraySpec LinkEntrySpec[]

---@class PackageSchema
---@field name? string
---@field package_name? OSPackageSpec
---@field enabled? boolean | fun(): boolean
---@field depends? PackageList
---@field links? LinksArraySpec
---@field excludes? TargetList
---@field templates? TargetList
---@field default_target? PathString
---@field on_install? HookAction
---@field on_deploy? HookAction

---@alias PackageItemSpec string | PackageSchema
---@alias PackageList PackageItemSpec[]

local t                 = require("tableshape").types
local inspect           = require("inspect")

-- 1. Atomic Validators
local any_command       = t.string
local path_string       = t.string
local target_list       = path_string + t.array_of(path_string)
local os_pkg_spec       = t.string + t.map_of(t.string, t.string)
local hook_action       = any_command + t.func + t.array_of(any_command + t.func)

-- 2. Link Component Validators
local link_obj_spec     = t.shape {
   source   = path_string:is_optional(),
   targets  = target_list:is_optional(),
   override = t.boolean:is_optional(),
   backup   = t.boolean:is_optional(),
}
local link_entry_spec   = link_obj_spec + t.map_of(path_string, target_list)
local links_array_spec  = t.array_of(link_entry_spec)

-- 3. Package Schema (Root)
local package_list -- Forward declaration for recursion

local package_base      = t.shape {
   -- TODO: `name` must be a valid filename path.
   name           = t.string:is_optional(),
   [1]            = t.string:is_optional(),
   package_name   = os_pkg_spec:is_optional(),
   enabled        = (t.boolean + t.func):is_optional(),
   depends        = t.proxy(function() return package_list end):is_optional(),
   links          = links_array_spec:is_optional(),
   excludes       = target_list:is_optional(),
   templates      = target_list:is_optional(),
   default_target = path_string:is_optional(),
   on_install     = hook_action:is_optional(),
   on_deploy      = hook_action:is_optional(),
}

local package_schema    = t.custom(function(val)
   local success, err = package_base(val)
   if not success then
      return nil, err
   end

   local has_named = val.name
   local has_indexed = val[1]

   if has_named and has_indexed then
      return nil, "provide 'name' OR [1], but not both"
   end

   if not has_named and not has_indexed then
      return nil, "package must have a name (at index [1] or as 'name' field)"
   end

   return true
end)

-- 4. Final Recursive Aggregator
-- local package_item_spec = t.custom(function(val)
--    if t.string(val) then return true end
--    local ok, err = package_schema(val)
--    if not ok then return nil, err end
--    return true
-- end) --TODO: a bit overkill, but it works...
local package_item_spec = (t.string + t.any) * package_schema
package_list            = t.array_of(package_item_spec):describe("List of Packages")

return {
   is_package = package_schema,
   is_package_item = package_item_spec,
   is_package_list = package_list,
}
