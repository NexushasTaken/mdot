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

local t = require("hybrid.types")
local inspect = require("inspect")

local M = {}

M.PackageSpec = t.map({
   name = t.string,
   -- enabled = t.union(t.string, t.func),
   -- depends = M.PackageConfigs,
   -- links = M.Links,
   -- excludes = M.Links,
})
M.PackageEntry = t.union(t.string, M.PackageSpec)
M.PackageConfigs = t.map_of(
   { t.number, t.string },
   { t.string, M.PackageEntry }
)

local ok, err = M.PackageConfigs({
   "git",
   hypr = {}, -- TODO: it only returns "field 'hypr' value: table: 0x560496eda5c0"
})
print(ok, inspect(err))
return M
