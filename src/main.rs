mod structs;
mod logger;
mod specs;

use std::env;

use structs::*;
use log::{debug, error, info, trace, warn};
use logger::setup_logger;
use mlua::{FromLua, Function, IntoLua, Lua, Result as LuaResult, Table};

const APPNAME: &str = "mdot";

impl Context {
    pub fn new() -> Option<Self> {
        Some(Self {
            lua: Lua::new(),
            config_dir: dirs::config_dir()?,
            appname: env::var("MDOT_APPNAME").unwrap_or(APPNAME.into()),
            packages: Default::default(),
            depends: Default::default(),
        })
    }

    #[inline]
    pub fn get_global<T: FromLua>(&self, key: impl IntoLua) -> LuaResult<T> {
        let globals = self.lua.globals();
        globals.get::<T>(key)
    }

    pub fn setup_path(&mut self) -> LuaResult<()> {
        let package: Table = self.get_global("package")?;
        let path: String = package.get::<String>("path")?;
        let named = self.config_dir.join(format!("{}/?.lua", self.appname));
        let init = self.config_dir.join(format!("{}/?/init.lua", self.appname));
        let path = format!("{};{};{}", path, named.display(), init.display());
        package.set("path", path)?;
        Ok(())
    }

    pub fn load_config(&self) -> LuaResult<Table> {
        let require: Function = self.get_global("require")?;
        let config: Table = require.call("mdot")?;
        Ok(config)
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    setup_logger()?;
    let mut ctx = Context::new().unwrap();
    ctx.setup_path()?;

    let pkgs: Table = ctx.load_config()?;
    ctx.parse_config(&pkgs)?;

    // info!("pkgs: {:#?}", pkgs);

    // info!("packaged: {:#?}", packages);

    info!("packages: {:#?}", ctx.packages);
    Ok(())
}
