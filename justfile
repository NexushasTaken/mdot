example-test: build
  #!/usr/bin/env bash
  eval $(luarocks --tree lua_modules path)
  XDG_CONFIG_HOME="$PWD/examples" MDOT_APPNAME="test" ./lua_modules/bin/mdot

example-hypr: build
  #!/usr/bin/env bash
  eval $(luarocks --tree lua_modules path)
  XDG_CONFIG_HOME="$PWD/examples" MDOT_APPNAME="conf" ./lua_modules/bin/mdot

test:
  #!/usr/bin/env bash
  eval $(luarocks --tree lua_modules path)
  luarocks --tree lua_modules test

cliff-bump:
  git cliff --bump > releasenotes.md

build:
  #!/usr/bin/env bash
  luarocks --tree lua_modules build

run *args="": build
  #!/usr/bin/env bash
  ./lua_modules/bin/mdot {{args}}

get-deps:
  #!/usr/bin/env bash
  luarocks --tree lua_modules install --only-deps ./mdot-0.1.0-1.rockspec
