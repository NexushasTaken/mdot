-- ~/.config/systemd/user also gets runtime symlinks (*.wants/), so link per file.
return spec {
  link("i3-session.service", "~/.config/systemd/user/i3-session.service"),
  link("i3-session.target", "~/.config/systemd/user/i3-session.target"),
  link("kanata.service", "~/.config/systemd/user/kanata.service"),
}
