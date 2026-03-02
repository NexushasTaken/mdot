mod logger;
mod specs;
mod structs;

use std::{env, error::Error, io::Error as IOError, path::PathBuf};

use log::{debug, error, info, trace, warn};
use logger::setup_logger;
use mlua::{Error as LuaError, FromLua, Function, IntoLua, Lua, Result as LuaResult, Table};
use structs::*;
use walkdir::WalkDir;

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

    fn load_config(&mut self) -> Result<(), Box<dyn Error>> {
        let pkgs: Table = self.get_config()?;
        self.parse_config(&pkgs)?;
        self.process_links()?;
        Ok(())
    }

    fn process_links(&mut self) -> Result<(), Box<dyn Error>> {
        for pkg in self.packages.values_mut() {
            if pkg.default_target.components().count() == 0 {
                pkg.default_target = self.config_dir.join(&pkg.name);
            } else if !pkg.default_target.exists() {
                return Err(
                    format!("default_target {:#?} doesn't exist", pkg.default_target).into(),
                );
            }

            let pkg_config_dir = self.pkgs_dir.join(&pkg.name);
            for link in &mut pkg.links {
                link.source = pkg_config_dir.join(&link.source).canonicalize()?;
                if !link.source.exists() {
                    return Err(LuaError::external(format!(
                        "{:?} doesn't exist",
                        link.source
                    )))?;
                }

                for target in link.targets.iter_mut() {
                    *target = (shellexpand::tilde(&target.display().to_string()))
                        .into_owned()
                        .into();

                    let exist = Err(LuaError::external(format!(
                        "{:?} exist, consider deleting it.",
                        target
                    )));

                    if target.exists() {
                        return exist?;
                    } else {
                        *target = pkg.default_target.join(&*target);
                        if target.exists() {
                            return exist?;
                        }
                    }
                }
            }

            if pkg.strategy == Strategy::Shallow {
                pkg.shallow_links(&self.pkgs_dir)?;
            } else if pkg.strategy == Strategy::Deep {
                pkg.deep_links(&self.pkgs_dir)?;
            }
        }
        Ok(())
    }
}

impl Package {
    fn shallow_links(&mut self, pkgs_dir: &PathBuf) -> Result<(), Box<dyn Error>> {
        let pkg_src = pkgs_dir.join(&self.name).canonicalize()?;

        let already_linked = self.links.iter_mut().any(|link| {
            if link.targets.contains(&self.default_target) {
                return true;
            }
            link.targets.push(pkg_src.clone());
            true
        });

        if !already_linked {
            self.links.push(Link {
                source: pkg_src,
                targets: vec![self.default_target.clone()],
            });
        }
        Ok(())
    }

    fn deep_links(&mut self, pkgs_dir: &PathBuf) -> Result<(), Box<dyn Error>> {
        let pkg_source_config_dir = pkgs_dir.join(&self.name);
        for entry in WalkDir::new(&pkg_source_config_dir) {
            let entry = entry?;
            if !entry.file_type().is_file() {
                continue;
            }

            let source_path = entry.into_path();
            let rel = source_path.strip_prefix(&pkg_source_config_dir)?;
            if self
                .excludes
                .iter()
                .find(|pattern_glob| glob::glob(pattern_glob).is_ok())
                .is_some()
            {
                break;
            }

            let target = self.default_target.join(rel);
            if let Some(link) = self.links.iter_mut().find(|p| p.source == source_path) {
                if link.targets.contains(&target) {
                    link.targets.push(target);
                }
            } else {
                self.links.push(Link {
                    source: source_path,
                    targets: vec![target],
                });
            }
        }
        Ok(())
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    setup_logger()?;
    let mut ctx = Context::new().unwrap();
    ctx.setup_path()?;

    ctx.load_config()?;

    // info!("pkgs: {:#?}", pkgs);

    // info!("packaged: {:#?}", packages);

    info!("packages: {:#?}", ctx.packages);
    Ok(())
}
