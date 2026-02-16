local inspect = require("inspect")
local types = require("hybrid.types")
local ts_types = require("tableshape").types

local t = types.map_of({ types.string, types.string }, { types.number, types.string })
-- local t = types.union(types.string, types.number)
print(t({}))
