local inspect = require("inspect")
local types = require("hybrid.types")
local ts_types = require("tableshape").types
local dbg = require("debugger")

local t = types.map_of(
   { types.number, types.string },
   { types.string, types.string }
)
-- local t = types.union(types.map({
--    name = types.string
-- }), types.map({
--    key = types.string
-- }))
local v = {
   -- [1] = "dev",
   -- name = 1
   name = "",
}
-- dbg()
local ok, err = t(v)
print(ok, inspect(err))
