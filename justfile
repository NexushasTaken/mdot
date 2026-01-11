example-test:
  XDG_CONFIG_HOME="$PWD/examples" MDOT_APPNAME="test" ./lua src/mdot.lua

example-hypr:
  XDG_CONFIG_HOME="$PWD/examples" MDOT_APPNAME="conf" ./lua src/mdot.lua

cliff-bump:
  git cliff --bump > releasenotes.md
