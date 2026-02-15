local types = require("hybrid.types")
local t = types.union(types.string, types.number)
print(t(1))

