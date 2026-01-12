example-test:
  #!/usr/bin/env bash
  eval $(luarocks --tree lua_modules path)
  XDG_CONFIG_HOME="$PWD/examples" MDOT_APPNAME="test" lua src/mdot.lua

example-hypr:
  #!/usr/bin/env bash
  eval $(luarocks --tree lua_modules path)
  XDG_CONFIG_HOME="$PWD/examples" MDOT_APPNAME="conf" lua src/mdot.lua

test:
  #!/usr/bin/env bash
  eval $(luarocks --tree lua_modules path)
  luarocks --tree lua_modules test

cliff-bump:
  git cliff --bump > releasenotes.md
