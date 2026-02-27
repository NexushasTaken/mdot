use log::{debug, error, info, trace, warn};
use mlua::{Error as LuaError, Function, Lua, Result as LuaResult, Table, Value};

use colored::*;
use std::{collections::HashMap, error::Error, io, iter::Map};

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

#[derive(Debug, Default)]
struct Link {
    source: String,
    targets: Vec<String>,
}

#[derive(Debug, Default)]
enum DependencyMode {
    #[default]
    Required,
    Optional,
}

#[derive(Debug, Default)]
struct Dependency {
    name: String,
    mode: DependencyMode,
    depends: Vec<Dependency>,
}

#[derive(Debug)]
enum Depend {
    Depend(Dependency),
    Package(Package),
}

#[derive(Debug, Default)]
struct Package {
    name: String,
    depends: Vec<Depend>,
    enabled: Option<Function>,
    platforms: Vec<String>,
    links: Vec<Link>,
    excludes: Vec<String>,
}

impl Package {
    fn new(name: String) -> Self {
        Self {
            name,
            ..Default::default()
        }
    }
}

#[derive(Debug, Default)]
struct Context {
    lua: Lua,
    packages: HashMap<String, Package>,
}

fn extract_name(tbl: &Table, key: Option<&Value>) -> LuaResult<String> {
    let idx_name: Option<String> = tbl.get(1).ok();
    let field_name: Option<String> = tbl.get("name").ok();

    // Only consider key if it's a string
    let key_name: Option<String> = match key {
        Some(Value::String(s)) => Some(s.to_str()?.to_string()),
        _ => None,
    };

    match (key_name, idx_name, field_name) {
        (Some(s1), None, None) => Ok(s1),
        (None, Some(s2), None) => Ok(s2),
        (None, None, Some(s3)) => Ok(s3),
        (None, None, None) => Err(LuaError::external(
            "Package must have either [1], [\"name\"], or named Package",
        )),
        _ => Err(LuaError::external(
            "Package cannot have more than one of [1], [\"name\"], or named Package",
        )),
    }
}

fn as_string_or_vec_string(value: Value) -> LuaResult<Vec<String>> {
    match value {
        Value::String(name) => Ok(vec![name.to_str()?.to_owned()]),
        Value::Table(platforms) => Ok(platforms
            .sequence_values::<String>()
            .collect::<LuaResult<Vec<String>>>()?),
        Value::Nil => Ok(vec![]),
        other => {
            return Err(LuaError::external(format!(
                "expected string or array of strings, got: {:?}",
                other
            )));
        }
    }
}

fn normalize_package(ctx: &mut Context, mut pkg: Package, tbl: &Table) -> LuaResult<Package> {
    pkg.enabled = match tbl.get("enabled")? {
        Value::Boolean(v) => Some(ctx.lua.create_function(move |_, ()| Ok(v))?),
        Value::Function(f) => Some(f),
        Value::Nil => Default::default(),
        other => {
            return Err(LuaError::external(format!(
                "expected boolean or function, got: {:?}",
                other
            )));
        }
    };

    pkg.platforms = as_string_or_vec_string(tbl.get("platforms")?)?;
    pkg.depends = match tbl.get("depends")? {
        Value::Table(ref dep) => normalize_packages(ctx, dep)?,
        Value::Nil => Default::default(),
        other => {
            return Err(LuaError::external(format!(
                "expected boolean or function, got: {:?}",
                other
            )));
        }
    };

    pkg.links = match tbl.get("links")? {
        Value::Table(links) => links
            .pairs::<String, Value>()
            .map(|pair| {
                let (src, targets) = pair?;
                Ok(Link {
                    source: src,
                    targets: as_string_or_vec_string(targets)?,
                })
            })
            .collect::<LuaResult<Vec<Link>>>()?,
        Value::Nil => Default::default(),
        other => {
            return Err(LuaError::external(format!(
                "expected table (Links), got: {:?}",
                other
            )));
        }
    };

    pkg.excludes = as_string_or_vec_string(tbl.get("excludes")?)?;

    Ok(pkg)
}

fn normalize_packages(ctx: &mut Context, tbl: &Table) -> LuaResult<Vec<Depend>> {
    let mut depends: Vec<Depend> = Vec::new();

    tbl.for_each(|named_key: Value, value_pkg: Value| {
        match named_key {
            Value::Integer(_) => match value_pkg {
                Value::String(_) => {
                    ctx.packages
                        .insert(value_pkg.to_string()?, Package::new(value_pkg.to_string()?));
                    depends.push(Depend::Depend(Dependency {
                        name: value_pkg.to_string()?,
                        mode: DependencyMode::Required,
                        ..Default::default()
                    }));
                }
                Value::Table(ref tbl) => {
                    let name: String = extract_name(tbl, None)?;
                    match tbl.get("mode")? {
                        Value::String(mode) => {
                            depends.push(Depend::Depend(Dependency {
                                name,
                                mode: match mode.to_str()?.as_ref() {
                                    "required" => DependencyMode::Required,
                                    "optional" => DependencyMode::Optional,
                                    _ => {
                                        return Err(LuaError::external(
                                            "expected literal string \"required\" or \"optional\"",
                                        ));
                                    }
                                },
                                ..Default::default()
                            }));
                        }
                        Value::Nil => {
                            let pkg = normalize_package(ctx, Package::new(name.clone()), tbl)?;
                            ctx.packages.insert(name.clone(), pkg);
                            depends.push(Depend::Depend(Dependency {
                                name,
                                mode: DependencyMode::Required,
                                ..Default::default()
                            }));
                        }
                        _ => {}
                    }
                }
                v => {
                    return Err(LuaError::external(format!("value: {:#?}", v)));
                }
            },
            Value::String(_) => match value_pkg {
                Value::Table(ref tbl) => {
                    let name: String = extract_name(tbl, Some(&named_key))?;
                    let pkg = normalize_package(ctx, Package::new(name.clone()), tbl)?;
                    ctx.packages.insert(name.clone(), pkg);
                    depends.push(Depend::Depend(Dependency {
                        name,
                        mode: DependencyMode::Required,
                        ..Default::default()
                    }));
                }
                ref v => {
                    return Err(LuaError::external(format!("value: {:#?}", v)));
                }
            },
            v => {
                return Err(LuaError::external(format!("key: {:#?}", v)));
            }
        }

        Ok(())
    })?;

    return Ok(depends);
}

fn packages_test(ctx: &mut Context) -> LuaResult<()> {
    let source: String = r#"
    return {
        "git",
        { name = "hyprland" },
        neovim = {
            depends = {
                { "vim", mode = "required" }
            },
            platforms = "linux",
        },
    }"#
    .into();

    let pkgs: Table = ctx.lua.load(source).eval()?;
    let packages = normalize_packages(ctx, &pkgs)?;

    info!("pkgs: {:#?}", pkgs);

    info!("packaged: {:#?}", packages);

    info!("ctx: {:#?}", ctx);
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    setup_logger()?;
    let mut ctx = Context::default();

    packages_test(&mut ctx)?;
    Ok(())
}
