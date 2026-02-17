---@diagnostic disable-next-line: lowercase-global
lu = require("luaunit")

require("tests.hybrid")

os.exit(lu.LuaUnit.run())
