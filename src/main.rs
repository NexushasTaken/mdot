use log::{debug, error, info, trace, warn};
use mlua::{Error as LuaError, Function, Lua, Result as LuaResult, Table, Value};

use colored::*;
use std::{collections::HashMap, error::Error, io};

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

fn value_to_string(v: &Value) -> LuaResult<String> {
    match v {
        Value::String(s) => Ok(s.to_str()?.to_owned()),
        _ => Err(LuaError::external(format!("expected string, got: {:?}", v))),
    }
}

fn extract_package_name(tbl: &Table, key: Option<&Value>) -> LuaResult<String> {
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

fn as_string_or_vec_string(value: &Value) -> LuaResult<Vec<String>> {
    match value {
        Value::String(name) => Ok(vec![name.to_str()?.to_owned()]),
        Value::Table(platforms) => Ok(platforms
            .sequence_values::<String>()
            .collect::<LuaResult<Vec<String>>>()?),
        Value::Nil => Ok(vec![]),
        other => Err(LuaError::external(format!(
            "expected string or array of strings, got: {:?}",
            other
        ))),
    }
}

fn ensure_package(ctx: &mut Context, name: String, pkg: Package) -> LuaResult<()> {
    if ctx.packages.contains_key(&name) {
        return Err(LuaError::external(
            format!("The \"{name}\" already exists",),
        ));
    }
    ctx.packages.insert(name, pkg);
    Ok(())
}

fn parse_enabled(ctx: &mut Context, tbl: &Table) -> LuaResult<Option<Function>> {
    match tbl.get("enabled")? {
        Value::Boolean(v) => Ok(Some(ctx.lua.create_function(move |_, ()| Ok(v))?)),
        Value::Function(f) => Ok(Some(f)),
        Value::Nil => Ok(None),
        other => Err(LuaError::external(format!(
            "expected boolean or function, got: {:?}",
            other
        ))),
    }
}

fn parse_links(_: &mut Context, tbl: &Table) -> LuaResult<Vec<Link>> {
    match tbl.get("links")? {
        Value::Table(links) => Ok(links
            .pairs::<String, Value>()
            .map(|pair| {
                let (src, targets) = pair?;
                Ok(Link {
                    source: src,
                    targets: as_string_or_vec_string(&targets)?,
                })
            })
            .collect::<LuaResult<Vec<Link>>>()?),
        Value::Nil => Ok(vec![]),
        other => {
            return Err(LuaError::external(format!(
                "expected table (Links), got: {:?}",
                other
            )));
        }
    }
}

fn parse_depends(ctx: &mut Context, tbl: &Table) -> LuaResult<Vec<Dependency>> {
    match tbl.get("depends")? {
        Value::Table(ref dep) => Ok(parse_dependencies(ctx, dep)?),
        Value::Nil => return Ok(vec![]),
        other => Err(LuaError::external(format!(
            "expected boolean or function, got: {:?}",
            other
        ))),
    }
}

fn create_package(ctx: &mut Context, name: String, tbl: &Table) -> LuaResult<Vec<Dependency>> {
    let pkg = Package {
        name: name.to_owned(),
        enabled: parse_enabled(ctx, tbl)?,
        platforms: as_string_or_vec_string(&tbl.get("platforms")?)?,
        links: parse_links(ctx, tbl)?,
        excludes: as_string_or_vec_string(&tbl.get("excludes")?)?,
    };

    ensure_package(ctx, name.to_owned(), pkg)?;
    parse_depends(ctx, tbl)
}

fn parse_dependencies(ctx: &mut Context, tbl: &Table) -> LuaResult<Vec<Dependency>> {
    let mut depends: Vec<Dependency> = Vec::new();

    tbl.for_each(|named_key: Value, value_pkg: Value| {
        match (&named_key, &value_pkg) {
            (Value::Integer(_), Value::String(_)) => {
                ensure_package(
                    ctx,
                    value_pkg.to_string()?,
                    Package::new(value_pkg.to_string()?),
                )?;
                depends.push(Dependency {
                    name: value_pkg.to_string()?,
                    mode: DependencyMode::Required,
                    ..Default::default()
                });
            }
            (Value::Integer(_), Value::Table(tbl)) => {
                let name: String = extract_package_name(tbl, None)?;
                match tbl.get(2)? {
                    Value::String(mode) => {
                        depends.push(Dependency {
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
                        });
                    }
                    Value::Nil => {
                        depends.push(Dependency {
                            name: name.to_owned(),
                            mode: DependencyMode::Required,
                            depends: create_package(ctx, name.to_owned(), tbl)?,
                            ..Default::default()
                        });
                    }
                    _ => {}
                }
            }
            (Value::String(_), Value::Table(tbl)) => {
                let name: String = extract_package_name(tbl, Some(&named_key))?;
                depends.push(Dependency {
                    name: name.to_owned(),
                    mode: DependencyMode::Required,
                    depends: create_package(ctx, name.to_owned(), tbl)?,
                    ..Default::default()
                });
            }
            (key, value) => {
                return Err(LuaError::external(format!(
                    "Invalid package definition: {:#?} = {:#?}",
                    key, value
                )));
            }
        }

        Ok(())
    })?;

    Ok(depends)
}

fn packages_test(ctx: &mut Context) -> LuaResult<()> {
    let source: String = r#"
    return {
        "git",
        {
            name = "hyprland",
            depends = {
                { "git", "required" },
                "waybar",
            },
        },
        neovim = {
            depends = {
                { "vim", "required" },
                { "git", "required" },
            },
            platforms = "linux",
        },
    }"#
    .into();

    let pkgs: Table = ctx.lua.load(source).eval()?;
    let packages = parse_dependencies(ctx, &pkgs)?;

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
