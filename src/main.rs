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

fn extract_package_name(tbl: &Table, key: Option<&Value>) -> LuaResult<String> {
    let names: Vec<String> = vec![
        tbl.get(1).ok(),
        tbl.get("name").ok(),
        // Only consider key if it's a string
        match key {
            Some(Value::String(s)) => Some(s.to_str()?.to_string()),
            _ => None,
        },
    ]
    .into_iter()
    .flatten()
    .collect();

    match names.len() {
        0 => Err(LuaError::external(
            "Package must have either [1], [\"name\"], or named Package",
        )),
        1 => Ok(names.first().unwrap().to_string()),
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

#[cfg(test)]
mod tests {
    use super::*;
    use mlua::{Function, Lua, Table, Value};

    // Helper to create a Context that uses the provided Lua instance
    fn ctx_with_lua(lua: Lua) -> Context {
        Context {
            lua,
            packages: std::collections::HashMap::new(),
        }
    }

    #[test]
    fn test_extract_package_name_variants_and_errors() {
        let lua = Lua::new();
        let key = Value::String(lua.create_string("named_pkg").unwrap());

        // case: index [1]
        let tbl: Table = lua.create_table().unwrap();
        tbl.set(1, "git").unwrap();
        assert_eq!(extract_package_name(&tbl, None).unwrap(), "git");

        // case: index ["name"]
        let tbl: Table = lua.create_table().unwrap();
        tbl.set("name", "neovim").unwrap();
        assert_eq!(extract_package_name(&tbl, None).unwrap(), "neovim");

        // key provided as string
        let tbl: Table = lua.create_table().unwrap();
        // no [1] or name
        assert_eq!(extract_package_name(&tbl, Some(&key)).unwrap(), "named_pkg");

        // error: none present
        let tbl: Table = lua.create_table().unwrap();
        assert!(extract_package_name(&tbl, None).is_err());

        // error: more than one present
        let tbl: Table = lua.create_table().unwrap();

        tbl.set(1, "a").unwrap();
        assert!(extract_package_name(&tbl, Some(&key)).is_err());

        let tbl: Table = lua.create_table().unwrap();
        tbl.set("name", "b").unwrap();
        assert!(extract_package_name(&tbl, Some(&key)).is_err());
    }

    #[test]
    fn test_as_string_or_vec_string_variants() {
        let lua = Lua::new();

        // string
        let s = lua.create_string("linux").unwrap();
        let v = Value::String(s);
        assert_eq!(
            as_string_or_vec_string(&v).unwrap(),
            vec!["linux".to_string()]
        );

        // table sequence
        let tbl: Table = lua.create_table().unwrap();
        tbl.set(1, "a").unwrap();
        tbl.set(2, "b").unwrap();
        let v_tbl = Value::Table(tbl);
        assert_eq!(
            as_string_or_vec_string(&v_tbl).unwrap(),
            vec!["a".to_string(), "b".to_string()]
        );

        // nil
        let v_nil = Value::Nil;
        assert_eq!(
            as_string_or_vec_string(&v_nil).unwrap(),
            Vec::<String>::new()
        );

        // invalid type
        let v_num = Value::Integer(10);
        assert!(as_string_or_vec_string(&v_num).is_err());
    }

    #[test]
    fn test_ensure_package_duplicate_error() {
        let lua = Lua::new();
        let mut ctx = ctx_with_lua(lua);

        let pkg = Package::new("git".to_string());
        ensure_package(&mut ctx, "git".to_string(), pkg).unwrap();

        // inserting again should error
        let pkg2 = Package::new("git".to_string());
        let res = ensure_package(&mut ctx, "git".to_string(), pkg2);
        assert!(res.is_err());
    }

    #[test]
    fn test_parse_enabled_boolean_function_and_nil() {
        let lua = Lua::new();
        let mut ctx = ctx_with_lua(lua);

        // boolean true -> wrapped function returning true
        let tbl: Table = ctx.lua.create_table().unwrap();
        tbl.set("enabled", true).unwrap();
        let f_opt = parse_enabled(&mut ctx, &tbl).unwrap();
        assert!(f_opt.is_some());
        let f = f_opt.unwrap();
        let res: bool = f.call(()).unwrap();
        assert!(res);

        // function provided -> returned as-is
        let tbl2: Table = ctx.lua.create_table().unwrap();
        let func: Function = ctx.lua.create_function(|_, ()| Ok(true)).unwrap();
        tbl2.set("enabled", func.clone()).unwrap();
        let f_opt2 = parse_enabled(&mut ctx, &tbl2).unwrap();
        assert!(f_opt2.is_some());
        let res2: bool = f_opt2.unwrap().call(()).unwrap();
        assert!(res2);

        // nil -> None
        let tbl3: Table = ctx.lua.create_table().unwrap();
        let f_opt3 = parse_enabled(&mut ctx, &tbl3).unwrap();
        assert!(f_opt3.is_none());

        // invalid -> error
        let tbl4: Table = ctx.lua.create_table().unwrap();
        tbl4.set("enabled", 123).unwrap();
        assert!(parse_enabled(&mut ctx, &tbl4).is_err());
    }

    #[test]
    fn test_parse_links_variants() {
        let lua = Lua::new();
        let mut ctx = ctx_with_lua(lua);

        // links = nil -> empty vec
        let tbl: Table = ctx.lua.create_table().unwrap();
        let links = parse_links(&mut ctx, &tbl).unwrap();
        assert!(links.is_empty());

        // links as table with string and array
        let tbl2: Table = ctx.lua.create_table().unwrap();
        let links_tbl: Table = ctx.lua.create_table().unwrap();
        links_tbl.set("src1", "target1").unwrap();

        let arr: Table = ctx.lua.create_table().unwrap();
        arr.set(1, "t1").unwrap();
        arr.set(2, "t2").unwrap();
        links_tbl.set("src2", Value::Table(arr)).unwrap();

        tbl2.set("links", Value::Table(links_tbl)).unwrap();

        let parsed = parse_links(&mut ctx, &tbl2).unwrap();
        // two links expected
        assert_eq!(parsed.len(), 2);
        // find src1 and src2
        let mut found_src1 = false;
        let mut found_src2 = false;
        for l in parsed {
            if l.source == "src1" {
                assert_eq!(l.targets, vec!["target1".to_string()]);
                found_src1 = true;
            } else if l.source == "src2" {
                assert_eq!(l.targets, vec!["t1".to_string(), "t2".to_string()]);
                found_src2 = true;
            }
        }
        assert!(found_src1 && found_src2);

        // invalid type for links
        let tbl3: Table = ctx.lua.create_table().unwrap();
        tbl3.set("links", 123).unwrap();
        assert!(parse_links(&mut ctx, &tbl3).is_err());
    }

    #[test]
    fn test_parse_dependencies_and_create_package_flow() {
        let lua = Lua::new();
        let mut ctx = ctx_with_lua(lua);

        // Use the same sample source string from packages_test
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

        let pkgs: Table = ctx.lua.load(&source).eval().unwrap();
        let packages = parse_dependencies(&mut ctx, &pkgs).unwrap();

        // top-level dependencies should include "git" and the hyprland table and neovim entry
        // The returned vector corresponds to the numeric entries only (not named keys),
        // so first element should be Dependency for "git" (string), second for hyprland table.
        assert!(packages.len() >= 2);

        // Ensure that packages were registered in ctx.packages for created packages
        // "git" should exist
        assert!(ctx.packages.contains_key("git"));
        // "hyprland" should exist
        assert!(ctx.packages.contains_key("hyprland"));
        // "neovim" should exist (named entry)
        assert!(ctx.packages.contains_key("neovim"));

        // Check that neovim package has platforms set to linux
        let neovim_pkg = ctx.packages.get("neovim").unwrap();
        assert_eq!(neovim_pkg.platforms, vec!["linux".to_string()]);
    }
}
