run:
  #!/usr/bin/bash
  eval $(luarocks --tree lua_modules path)
  lua5.4 mdot/init.lua

test:
  #!/usr/bin/bash
  eval $(luarocks --tree lua_modules path)
  luarocks test

build:
  #!/usr/bin/bash
  luarocks --tree lua_modules build

fetch: build
  #!/usr/bin/bash
  luarocks --tree lua_modules remove ./mdot-dev-1.rockspec

rocks *args="":
  #!/usr/bin/bash
  luarocks --tree lua_modules {{args}}
