# Package Spec

> This is an unfinished specification, it will be updated in the future as more features are added.

```lua
---@alias OSPackageSpec string | table<string, string>
---@alias PathString string
---@alias TargetList PathString | PathString[]

---@class LinkSpec
---@field source? PathString
---@field targets? TargetList
---@field [1]? PathString
---@field [2]? TargetList

---@class Links : {
---   [integer]: LinkSpec,     -- for { "s", "t" } or { source = "s", targets = "t" }
---   [PathString]: TargetList, -- for ["path/to/file"] = "target" or ["path/to/file"] = { "targetA", "targetB" }
---}

---@class PackageSpec
---@field [1]? string
---@field name? string
---@field enabled? boolean | fun(): boolean
---@field depends? PackageConfigs
---@field links? Links
---@field excludes? TargetList

---@alias DependencyMode "required" | "optional"

---@class DependencySpec
---@field [1] string -- The package name
---@field type? DependencyMode -- Defaults to "required"

---@alias PackageEntry string | DependencySpec | PackageSpec
---@class PackageConfigs : {
---   [integer]: PackageEntry,
---   [string]: PackageSpec,
---}
```
