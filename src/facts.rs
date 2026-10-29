//! Facts about this machine that Lua sees as `mdot.os` and `mdot.dirs`
//! (ADR 0040, 0043, 0044). They are computed once, before any Lua runs, so
//! loading stays pure: a spec reads values, it never asks the OS itself.

use std::fs;
use std::path::PathBuf;

/// `mdot.os`. `None` becomes `nil` in Lua.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OsFacts {
    pub name: String,
    pub family: String,
    pub arch: String,
    pub bitness: u32,
    pub distribution: Option<String>,
    pub version: Option<String>,
    pub codename: Option<String>,
    pub edition: Option<String>,
    /// The name used to pick `hosts/<name>.lua` (real or `preview`/`--host`).
    pub hostname: String,
}

/// The 19 names of `mdot.dirs`, in the order design.typ lists them. Lua code
/// reading a name outside this list gets an error.
pub const DIR_NAMES: [&str; 19] = [
    "home", "cache", "config", "config_local", "data", "data_local", "executable",
    "preference", "runtime", "state", "audio", "desktop", "document", "download", "font",
    "picture", "public", "template", "video",
];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Facts {
    pub os: OsFacts,
    /// Same order as `DIR_NAMES`. `None` = this dir does not exist on this OS.
    pub dirs: Vec<(&'static str, Option<String>)>,
}

impl Facts {
    /// The real machine's facts, with `hostname` as the host name to use.
    pub fn of_this_machine(hostname: &str) -> Facts {
        let release = read_os_release();
        let field = |key: &str| -> Option<String> {
            release
                .iter()
                .find(|(k, _)| k == key)
                .map(|(_, v)| v.clone())
                .filter(|v| !v.is_empty())
        };

        let os = OsFacts {
            name: std::env::consts::OS.to_string(),
            family: std::env::consts::FAMILY.to_string(),
            arch: std::env::consts::ARCH.to_string(),
            // Pointer width of the build target: 64 on x86_64 and aarch64.
            bitness: usize::BITS,
            distribution: field("ID").map(|s| s.to_ascii_lowercase()),
            // TODO(build): "as the OS reports it" on macOS/Windows; os-release
            // only covers Linux. `edition` has no source yet on any OS.
            version: field("VERSION_ID"),
            codename: field("VERSION_CODENAME"),
            edition: None,
            hostname: hostname.to_string(),
        };

        Facts { os, dirs: this_machine_dirs() }
    }
}

// `fn() -> Option<PathBuf>` is a function pointer, like `PathBuf *(*)(void)` in C.
fn this_machine_dirs() -> Vec<(&'static str, Option<String>)> {
    let getters: [fn() -> Option<PathBuf>; 19] = [
        dirs::home_dir, dirs::cache_dir, dirs::config_dir, dirs::config_local_dir,
        dirs::data_dir, dirs::data_local_dir, dirs::executable_dir, dirs::preference_dir,
        dirs::runtime_dir, dirs::state_dir, dirs::audio_dir, dirs::desktop_dir,
        dirs::document_dir, dirs::download_dir, dirs::font_dir, dirs::picture_dir,
        dirs::public_dir, dirs::template_dir, dirs::video_dir,
    ];
    DIR_NAMES
        .iter()
        .zip(getters)
        .map(|(name, get)| {
            // "absolute path string without a trailing separator": PathBuf never
            // keeps one, and the dirs crate only returns absolute paths.
            let value = get().map(|p| p.to_string_lossy().into_owned());
            (*name, value)
        })
        .collect()
}

/// `KEY=value` pairs of /etc/os-release; empty when there is none (non-Linux).
fn read_os_release() -> Vec<(String, String)> {
    let Ok(text) = fs::read_to_string("/etc/os-release") else {
        return Vec::new();
    };
    text.lines()
        .filter_map(|line| line.split_once('='))
        .map(|(k, v)| (k.trim().to_string(), v.trim().trim_matches('"').to_string()))
        .collect()
}
