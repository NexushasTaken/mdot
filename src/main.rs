mod logger;
mod specs;

use log::{debug, error, info, trace, warn};
use logger::setup_logger;
use mlua::{Function, Lua, Result as LuaResult, StdLib, Table};
use specs::*;
use std::{env, path::PathBuf, rc::Rc};

const APPNAME: &str = "mdot";

#[derive(Debug)]
struct Context {
    lua: Rc<Lua>,
    spec_ctx: SpecContext,
    config_dir: PathBuf,
    appname: String,
}

impl Context {
    fn new() -> Option<Self> {
        let lua = Rc::new(Lua::new());

        Some(Self {
            lua: lua.clone(),
            spec_ctx: SpecContext::new(lua.clone()),
            config_dir: dirs::config_dir()?,
            appname: env::var("MDOT_APPNAME").unwrap_or(APPNAME.into()),
        })
    }

    fn setup_path(&mut self) -> LuaResult<()> {
        let globals = self.spec_ctx.lua.globals();
        let package: Table = globals.get("package")?;
        let path: String = package.get::<String>("path")?;
        let named = self.config_dir.join(format!("{}/?.lua", self.appname));
        let init = self.config_dir.join(format!("{}/?/init.lua", self.appname));
        let path = format!("{};{};{}", path, named.display(), init.display());
        package.set("path", path)?;
        Ok(())
    }

    fn load_config(&self) -> LuaResult<Table> {
        let globals = self.spec_ctx.lua.globals();
        let require: Function = globals.get("require")?;
        let config: Table = require.call("mdot")?;
        Ok(config)
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    setup_logger()?;
    // env::set_var("CARGO_PKG_NAME", "");
    let mut ctx = Context::new().unwrap();
    ctx.setup_path()?;

    let pkgs: Table = ctx.load_config()?;
    ctx.spec_ctx.parse_config(&pkgs)?;

    // info!("pkgs: {:#?}", pkgs);

    // info!("packaged: {:#?}", packages);

    info!("ctx: {:#?}", ctx);
    Ok(())
}
