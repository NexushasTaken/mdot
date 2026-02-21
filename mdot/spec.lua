---@alias spec.Command string
---@alias spec.HookAction spec.Command | fun() | (spec.Command | fun())[]

---@alias spec.OSPackageSpec string | table<string, string>
---@alias spec.PathString string
---@alias spec.TargetList spec.PathString | spec.PathString[]

---@alias spec.Links table<spec.PathString, spec.TargetList>

---@class spec.Package
---@field enabled? boolean | fun(): boolean
---@field depends? spec.Packages
---@field links? spec.Links
---@field excludes? spec.TargetList

---@alias spec.Packages table<string, spec.Package>

local t = require("tableshape").types
local inspect = require("inspect")
local log = require("mdot.log")
local dbg = require("debugger")

local M = {}

M.PathString = t.string
M.TargetList = M.PathString + t.array_of(M.PathString)
M.Links = t.map_of(M.PathString, M.TargetList)

M.Package = t.shape({
   enabled = (t.boolean + t.func):is_optional(),
   depends = t.proxy(function() return M.Packages end):is_optional(),
   links = M.Links:is_optional(),
   excludes = M.TargetList:is_optional(),
})

M.Packages = t.map_of(t.string, M.Package)

return M
