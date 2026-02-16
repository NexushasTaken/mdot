local inspect = require("inspect")
local types = require("hybrid.types")
local ts_types = require("tableshape").types

local t = types.map({
   types.string,
   key = types.string,
   tbl = types.union(types.string, types.number),
})
print(t({"", key = "", tbl = {}}))
