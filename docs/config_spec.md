# Package Spec

> This is an unfinished specification, it will be updated in the future as more features are added.

```lua
---@alias OSPackageSpec string | table<string, string>
---@alias PathString string
---@alias TargetList PathString | PathString[]
---@alias Platforms string | string[]

---@alias Links table<PathString, TargetList>

---@class Package
---@field [1]? string
---@field name? string
---@field enabled? boolean | fun(): boolean -- wrapped boolean into Function that returns it.
---@field platforms? Platforms
---@field depends? Dependencies
---@field links? Links
---@field excludes? TargetList

---@alias DependencyMode "required" | "optional"

---@class Dependency
---@field [1] string
---@field mode? DependencyMode -- Defaults to "required"

---@alias Dependencies string | Dependency | Package

---@alias PackageEntry string | Package

---@class PackageConfigs : {
---   [integer]: PackageEntry,
---   [string]: Package,
---}
```
