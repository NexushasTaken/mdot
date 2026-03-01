mod logger;
mod specs;
use std::env;

use logger::setup_logger;

use log::{debug, error, info, trace, warn};
use mlua::{StdLib, Table};
use specs::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    setup_logger()?;
    let mut ctx = SpecContext::default();

    let source: String = r#"
    return {
        "git",
        {
            name = "hyprland",
            enabled = false,
            depends = {
                { "git", "required" },
                "waybar",
            },
            excludes = "config",
        },
        neovim = {
            enabled = function() return true end,
            depends = {
                { "vim", "required" },
                { "git", "required" },
            },
            platforms = "linux",
            excludes = { "config", "user" },
        },
    }"#
    .into();

    let globals = ctx.lua.globals();
    let package: Table = globals.get("package")?;
    let path: String = package.get::<String>("path")?;

    info!("package: {:#?}", package);
    info!("{:#?}", path);
    info!("{:#?}", dirs::config_dir());
    info!("{:#?}", env::var("XDG_CONFIG_HOME"));

    let pkgs: Table = ctx.lua.load(source).eval()?;
    parse_config(&mut ctx, &pkgs)?;

    // info!("pkgs: {:#?}", pkgs);

    // info!("packaged: {:#?}", packages);

    // info!("ctx: {:#?}", ctx);
    Ok(())
}

