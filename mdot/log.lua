local ll = require("logging")
local console = require("logging.console")
local ansicolors = require("ansicolors")

local log = console({
   logPatterns = {
      [ll.INFO] = ansicolors("%{green}%level%{reset} %message\n"),
      [ll.DEBUG] = ansicolors("%{cyan}%level%{reset} %message %{reset}(%source)\n"),
      [ll.WARN] = ansicolors("%{yellow}%level%{reset} %message\n"),
      [ll.ERROR] = ansicolors("%{red bright}%level%{reset} %message %{reset}(%source)\n"),
      [ll.FATAL] = ansicolors("%{magenta bright}%level%{reset} %message %{reset}(%source)\n"),
   }
})

return log
