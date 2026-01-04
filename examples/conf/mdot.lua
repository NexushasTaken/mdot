return {
   pkgs.uwsm,
   pkgs.hyprland,
   bash = {
      exclude = "*",
      links = {
         ["bashrc.sh"] = "~/.bashrc"
      }
   }
}
