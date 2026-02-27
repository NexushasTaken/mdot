# Package Spec

> This is an unfinished specification, it will be updated in the future as more features are added.

```lua
---@alias OSPackageSpec string | table<string, string>
---@alias PathString string
---@alias TargetList PathString | PathString[]
---@alias Platforms string | string[]

---@alias Links table<PathString, TargetList>

---@class PackageSpec
---@field [1]? string
---@field name? string
---@field enabled? boolean | fun(): boolean
---@field platforms? Platforms
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
