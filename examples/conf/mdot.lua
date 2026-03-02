return {
   "uwsm",
   {
      "hyprland",
      strategy = "deep",
   },
   {
      "bash",
      excludes = "*",
      links = {
         ["bashrc.sh"] = { "bashrc-config.sh" }
      }
   }
}
