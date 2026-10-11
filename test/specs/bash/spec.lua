return spec {
  file.link("config", "~/.config/bash"),
  file.link("config/bashrc.sh", "~/.bashrc"),
  file.link("config/bash_profile.sh", "~/.bash_profile"),
}
