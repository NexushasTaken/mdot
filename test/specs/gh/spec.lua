-- ~/.config/gh also holds hosts.yml (auth tokens), so link only the file.
return spec {
  link("config.yml", "~/.config/gh/config.yml"),
}
