-- ~/.cargo holds registry, bin, etc. Link the file only.
return spec {
  link("config.toml", "~/.cargo/config.toml"),
}
