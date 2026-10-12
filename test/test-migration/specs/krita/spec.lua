-- ~/.config is shared, so link the files one by one.
return spec {
  file.link("kritarc", "~/.config/kritarc"),
  file.link("kritadisplayrc", "~/.config/kritadisplayrc"),
}
