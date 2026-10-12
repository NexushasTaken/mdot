return spec {
  file.link { "Xresources", "xinitrc", "xsession", "gtkrc-2.0", into = "~", dot = true },
}
