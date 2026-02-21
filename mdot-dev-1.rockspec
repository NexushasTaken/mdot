rockspec_format = "3.0"
package = "mdot"
version = "dev-1"
source = {
   url = "*** please add URL for source tarball, zip or repository here ***"
}
description = {
   homepage = "https://github.com/NexushasTaken/mdot",
   license = "MIT"
}
dependencies = {
   "argparse",
   "platformdirs",
   "luafilesystem",
   "inspect",
   "penlight",
   "sysdetect",
   "tableshape",
   "lualogging",
   "ansicolors",
}
build_dependencies = {
}
build = {
   type = "builtin",
   install = {
      bin = {
         mdot = "./mdot/init.lua",
      }
   },
}
test_dependencies = {
   "luaunit",
   "inspect",
   "penlight",
}
test = {
   type = "command",
   command = "lua tests/test.lua -o TAP",
}
