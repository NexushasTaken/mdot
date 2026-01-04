rockspec_format = "3.0"
package = "mdot"
version = "0.1.0"
source = {
   url = ""
}
description = {
   homepage = "https://github.com/NexushasTaken/mdot",
   license = "MIT"
}
dependencies = {
  "argparse",
  "platformdirs",
  "luafilesystem",
  "loglua",
  "inspect",
  "penlight",
}
build_dependencies = {}
build = {
   type = "builtin",
   modules = {
      mdot = "./src/mdot.lua"
   },
   install = {
      bin = {
         mdot = "./src/mdot.lua",
      },
   }
}

test_dependencies = {
  "luaunit"
}

test = {
  type = "command",
  command = "./lua src/tests/test.lua -o TAP",
}
