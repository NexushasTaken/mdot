-- ~/.config/systemd/user also gets runtime symlinks (*.wants/), so link per file.
return spec {
  file.link { "i3-session.service", "i3-session.target", "kanata.service",
               into = "~/.config/systemd/user" },
}
