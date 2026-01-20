rockspec_format = "3.0"
package = "mdot"
version = "0.1.0-1"
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
  "sysdetect",
}
build_dependencies = {}
build = {
   type = "builtin",
   modules = {
      mdot = "./mdot/init.lua",
      validation = "./external/validation.lua",
   },
   install = {
      bin = {
         mdot = "./mdot/init.lua",
      },
   }
}

test_dependencies = {
  "luaunit"
}

test = {
  type = "command",
  command = "lua src/tests/test.lua -o TAP",
}
