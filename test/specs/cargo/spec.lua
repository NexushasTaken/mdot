-- ~/.cargo holds registry, bin, etc. Link the file only.
return spec {
  file.link("config.toml", "~/.cargo/config.toml"),
}
