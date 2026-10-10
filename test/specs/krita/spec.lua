-- ~/.config is shared, so link the files one by one.
return spec {
  link("kritarc", "~/.config/kritarc"),
  link("kritadisplayrc", "~/.config/kritadisplayrc"),
}
