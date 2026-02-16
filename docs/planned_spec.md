```lua
---@alias Command string
---@alias HookAction Command | fun() | (Command | fun())[]

---@alias OSPackageSpec string | table<string, string>
---@alias PathString string
---@alias TargetList PathString | PathString[]

---@class LinkSpec
---@field source? PathString
---@field targets? TargetList
---@field [1]? PathString
---@field [2]? TargetList
---@field backup? boolean
---@field override? boolean

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

---@alias PackageEntry string | PackageSpec
---@class PackageConfigs : {
---   [integer]: PackageEntry,
---   [string]: PackageSpec,
---}
```
