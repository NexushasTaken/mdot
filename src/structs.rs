use std::{collections::HashMap, env, path::PathBuf, rc::Rc};

use mlua::{FromLua, Function, IntoLua, Lua, Result as LuaResult, Table};

#[derive(Debug, Default)]
pub struct Link {
    pub source: String,
    pub targets: Vec<String>,
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
    pub default_target: Option<String>,
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
    pub config_dir: PathBuf,
    pub appname: String,

    pub packages: HashMap<String, Package>,
    pub depends: Vec<Dependency>,
}
