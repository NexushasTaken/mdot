mod logger;
mod specs;
use logger::setup_logger;

use log::{debug, error, info, trace, warn};
use mlua::{StdLib, Table};
use specs::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    setup_logger()?;
    let mut ctx = Context::default();

    ctx.lua.load_std_libs(StdLib::PACKAGE)?;

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

    let pkgs: Table = ctx.lua.load(source).eval()?;
    let packages = parse_dependencies(&mut ctx, &pkgs)?;

    info!("pkgs: {:#?}", pkgs);

    info!("packaged: {:#?}", packages);

    info!("ctx: {:#?}", ctx);
    Ok(())
}

