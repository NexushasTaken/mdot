mod logger;
mod specs;
mod structs;

use std::{env, error::Error, io::Error as IOError, path::PathBuf};

use log::{debug, error, info, trace, warn};
use logger::setup_logger;
use mlua::{Error as LuaError, FromLua, Function, IntoLua, Lua, Result as LuaResult, Table};
use structs::*;
use walkdir::{DirEntry, WalkDir};

const APPNAME: &str = "mdot";

impl Context {
    fn new() -> Option<Self> {
        let appname = env::var("MDOT_APPNAME").unwrap_or(APPNAME.into());
        let config_dir = dirs::config_dir()?;
        let app_config_dir: PathBuf = env::var("MDOT_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or(dirs::config_dir()?)
            .join(&appname);
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
                let files = pkg.get_config_files(&self.pkgs_dir)?;
                pkg.deep_links(&self.pkgs_dir, &files)?;
            }
        }
        Ok(())
    }

    fn show_links(&self) {
        for pkg in self.packages.values() {
            for link in &pkg.links {
                info!(
                    "{:?}: {:?} -> {:#?}",
                    pkg.strategy, link.source, link.targets
                );
            }
        }
    }
}

impl Package {
    pub fn get_config_files(&self, pkgs_dir: &PathBuf) -> Result<Vec<PathBuf>, Box<dyn Error>> {
        let pkg_source_dir = pkgs_dir.join(&self.name);
        let mut files: Vec<PathBuf> = vec![];
        for entry in WalkDir::new(&pkg_source_dir) {
            let entry = entry?;
            if entry.file_type().is_file() {
                files.push(entry.into_path());
            }
        }
        Ok(files)
    }

    pub fn get_or_create_targets(&mut self, source: &PathBuf) -> &mut Vec<PathBuf> {
        let index = self.links.iter().position(|l| l.source == *source);

        match index {
            Some(i) => &mut self.links[i].targets,
            None => {
                self.links.push(Link {
                    source: source.to_owned(),
                    targets: Vec::new(),
                });
                &mut self.links.last_mut().unwrap().targets
            }
        }
    }

    fn shallow_links(&mut self, pkgs_dir: &PathBuf) -> Result<(), Box<dyn Error>> {
        let pkg_src = pkgs_dir.join(&self.name).canonicalize()?;

        let target_to_add = self.default_target.clone();

        let targets = self.get_or_create_targets(&pkg_src);

        if !targets.contains(&target_to_add) {
            targets.push(target_to_add);
        }

        Ok(())
    }

    fn deep_links(&mut self, pkgs_dir: &PathBuf, files: &[PathBuf]) -> Result<(), Box<dyn Error>> {
        let pkg_source_config_dir = pkgs_dir.join(&self.name);
        for entry in files {
            if self
                .excludes
                .iter()
                .find(|pattern_glob| glob::glob(pattern_glob).is_ok())
                .is_some()
            {
                break;
            }

            let rel = entry.strip_prefix(&pkg_source_config_dir)?;
            let target = self.default_target.join(rel);
            let targets = self.get_or_create_targets(&entry);
            targets.push(target);
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

    // info!("packages: {:#?}", ctx.packages);
    ctx.show_links();
    Ok(())
}
