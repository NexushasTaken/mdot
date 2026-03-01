use std::{collections::HashMap, env, path::PathBuf, rc::Rc};

use mlua::{FromLua, Function, IntoLua, Lua, Result as LuaResult, Table};

#[derive(Debug, Default)]
pub struct Link {
    pub source: PathBuf,
    pub targets: Vec<PathBuf>,
}

#[derive(Debug, Default)]
pub enum DependencyMode {
    #[default]
    Required,
    Optional,
}

#[derive(Debug, Default)]
pub struct Dependency {
    pub name: String,
    pub mode: DependencyMode,
    pub depends: Vec<Dependency>,
}

#[derive(Debug)]
pub enum Depend {
    Depend(Dependency),
    Package(Package),
}

#[derive(Debug, Default)]
pub struct Package {
    pub name: String,
    pub default_target: PathBuf,
    pub enabled: Option<Function>,
    pub platforms: Vec<String>,
    pub links: Vec<Link>,
    pub excludes: Vec<String>,
}

impl Package {
    pub fn new(name: String) -> Self {
        Self {
            name,
            ..Default::default()
        }
    }
}

#[derive(Debug)]
pub struct Context {
    pub lua: Lua,
    pub appname: String,

    pub config_dir: PathBuf,
    pub app_config_dir: PathBuf,
    pub pkgs_dir: PathBuf,

    pub packages: HashMap<String, Package>,
    pub depends: Vec<Dependency>,
}
