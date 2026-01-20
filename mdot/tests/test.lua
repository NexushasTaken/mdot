lu = require("luaunit")

TestNormalizedPackage = require("src.tests.test_normalized_package")
TestNormalizedPackageDependencies = require("src.tests.test_normalized_package_dependencies")

os.exit(lu.LuaUnit.run())
