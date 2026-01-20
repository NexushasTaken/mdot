lu = require("luaunit")

TestNormalizedPackage = require("mdot.tests.test_normalized_package")
TestNormalizedPackageDependencies = require("mdot.tests.test_normalized_package_dependencies")

os.exit(lu.LuaUnit.run())
