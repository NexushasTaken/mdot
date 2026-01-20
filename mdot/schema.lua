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

local v = require("validation")
local inspect = require("inspect")

local is_os_package = v.one_of(
   v.is_string(),
   v.is_array(v.is_string(), true)
)
local is_path = v.is_string()
local is_targets = v.one_of(
   is_path,
   v.is_array(is_path)
)

local is_link_entry = v.is_table {
   source = v.optional(is_path),
   targets = v.optional(is_targets),
   override = v.optional(v.is_boolean()),
   backup = v.optional(v.is_boolean()),
}
local is_links = v.is_array(
   v.one_of(
      v.table_key_value(
         is_path,
         is_targets
      ),
      is_link_entry
   )
)

local is_package = v.is_table {
   enabled = v.optional(v.one_of(
      v.is_boolean(), v.is_function()
   )),
   --depends = v.optional(v.is_boolean()),
   name = v.optional(v.is_string()),
   app_name = v.optional(v.is_string()),
   package_name = v.optional(is_os_package),
   default_target = v.optional(is_path),
   links = v.optional(is_links),
   exclude = v.optional(is_targets),
   templates = v.optional(is_templates),
}
local is_package2 = v.one_of(
   is_package,
   v.is_string()
)

local val, err = is_package2({
   enabled = ""
})
print(inspect(val), inspect(err))

return {
   is_package = is_package,
   is_package2 = is_package2,
}
