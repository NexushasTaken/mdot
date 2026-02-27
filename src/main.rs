use log::{debug, error, info, trace, warn};
use mlua::{Lua, Table, Error, Value, LuaSerdeExt};

use colored::*;
use std::io;

fn setup_logger() -> Result<(), fern::InitError> {
  fern::Dispatch::new()
    .format(|out, message, record| {
      // Map log levels to specific colors
      let level_color = match record.level() {
        log::Level::Error => Color::Red,
        log::Level::Warn => Color::Yellow,
        log::Level::Info => Color::Green,
        log::Level::Debug => Color::Cyan,
        log::Level::Trace => Color::Magenta,
      };

      // Format: [LEVEL]: message
      out.finish(format_args!(
          "[{}] {}",
          record.level().to_string().color(level_color).bold(),
          message
      ))
    })
  .level(log::LevelFilter::Debug)
    .chain(io::stdout())
    .apply()?;
  Ok(())
}

#[derive(Debug)]
struct Package {
  name: String
}

impl Package {
  fn new(name: String) -> Self {
    Self {
      name,
    }
  }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
  setup_logger()?;
  let mut lua = Lua::new();

  let source: String = r#"return {
    "git",
    { name = "hyprland" },
    neovim = {},
  }"#.into();

  let mut packages: Vec<Package> = vec![];
  let pkgs: Table = lua.load(source).eval()?;
  pkgs.for_each(|key: Value, value: Value| -> Result<(), Error> {
    match key {
      Value::Integer(idx) => {
        match value {
          Value::String(ref name) => {
            packages.push(Package::new(lua.from_value(value)?));
          },
          Value::Table(ref tbl) => {
            let name: Value = tbl.get("name")?;
            packages.push(Package::new(lua.from_value(name)?));
          },
          v => error!("value: {:#?}", v),
        }
      },
      Value::String(ref name) => {
        match value {
          Value::Table(ref tbl) => {
            if let Ok(name) = tbl.get::<String>("name") {
              error!("has name: {:#?}", name);
            }
            packages.push(Package::new(lua.from_value(key)?));
          },
          ref v => error!("value: {:#?}", v),
        }
      },
      v => error!("key: {:#?}", v),
    }
    Ok(())
  })?;
  info!("pkgs: {:#?}", pkgs);

  info!("packaged: {:#?}", packages);
  Ok(())
}

