---@diagnostic disable: lowercase-global
lu = require("luaunit")
inspect = require("inspect")

require("tests.hybrid")
require("tests.mdot")

os.exit(lu.LuaUnit.run())
