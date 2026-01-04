example-test:
  MDOT_CONFIG_PATH="$PWD/examples" MDOT_APPNAME="test" ./lua src/mdot.lua

example-hypr:
  MDOT_CONFIG_PATH="$PWD/examples" MDOT_APPNAME="conf" ./lua src/mdot.lua
