mod logger;
mod specs;
mod structs;

use std::{env, error::Error, path::PathBuf};

use log::{debug, error, info, trace, warn};
use logger::setup_logger;
use mlua::{Error as LuaError, FromLua, Function, IntoLua, Lua, Result as LuaResult, Table};
use structs::*;

const APPNAME: &str = "mdot";

impl Context {
    fn new() -> Option<Self> {
        let appname = env::var("MDOT_APPNAME").unwrap_or(APPNAME.into());
        let config_dir = dirs::config_dir()?;
        let app_config_dir = config_dir.join(&appname);
        let pkgs_dir = app_config_dir.join("pkgs");

        Some(Self {
            lua: Lua::new(),
            appname,
            config_dir,
            app_config_dir,
            pkgs_dir,
            packages: Default::default(),
            depends: Default::default(),
        })
    }

    #[inline]
    fn get_global<T: FromLua>(&self, key: impl IntoLua) -> LuaResult<T> {
        let globals = self.lua.globals();
        globals.get::<T>(key)
    }

    fn setup_path(&mut self) -> LuaResult<()> {
        let package: Table = self.get_global("package")?;
        let path: String = package.get::<String>("path")?;
        let named = self
            .app_config_dir
            .join(format!("{}/?.lua", self.app_config_dir.display()));
        let init = self
            .app_config_dir
            .join(format!("{}/?/init.lua", self.app_config_dir.display()));
        let path = format!("{};{};{}", path, named.display(), init.display());
        package.set("path", path.clone())?;
        Ok(())
    }

    fn get_config(&self) -> LuaResult<Table> {
        let require: Function = self.get_global("require")?;
        let config: Table = require.call("mdot")?;
        Ok(config)
    }

    fn load_config(&mut self) -> LuaResult<()> {
        let pkgs: Table = self.get_config()?;
        self.parse_config(&pkgs)?;
        self.resolve_links()?;
        Ok(())
    }

    fn resolve_links(&mut self) -> LuaResult<()> {
        for pkg in self.packages.values_mut() {
            pkg.default_target = self.config_dir.join(&pkg.name);

            let pkg_config_dir = self.pkgs_dir.join(&pkg.name);
            for link in &mut pkg.links {
                link.source = pkg_config_dir.join(&link.source);
                if !link.source.exists() {
                    return Err(LuaError::external(format!(
                        "{:?} doesn't exist",
                        link.source
                    )));
                }

                for target in link.targets.iter_mut() {
                    *target = (shellexpand::tilde(&target.display().to_string()))
                        .into_owned()
                        .into();
                    if !target.exists() {
                        return Err(LuaError::external(format!(
                            "{:?} exist, consider deleting it.",
                            target
                        )));
                    }
                }
            }
        }
        Ok(())
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    setup_logger()?;
    let mut ctx = Context::new().unwrap();
    ctx.setup_path()?;

    info!("pkgs_dir: {:?}", ctx.pkgs_dir);
    ctx.load_config()?;

    // info!("pkgs: {:#?}", pkgs);

    // info!("packaged: {:#?}", packages);

    info!("packages: {:#?}", ctx.packages);
    Ok(())
}
