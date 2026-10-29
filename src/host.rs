//! Which host file to load (ADR 0070, 0071, 0079).
//!
//! Every error here exits with 2 (ADR 0079). A name that only breaks the
//! RFC 1123 format is a warning, and mdot continues.

use crate::error::Error;
use std::path::Path;

/// The real hostname, lowercased (ASCII only). Returns the name and the
/// format warning to show once for this run, if any.
pub fn real_hostname() -> Result<(String, Option<String>), Error> {
    let raw = read_os_hostname()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| Error::failed("cannot determine the hostname; set one"))?;
    let name = raw.to_ascii_lowercase();
    check_host_name(&name)?;
    let warning = (!is_rfc1123(&name)).then(|| {
        format!("hostname \"{name}\" is not a valid hostname (only a-z, 0-9, '-' and '.')")
    });
    Ok((name, warning))
}

/// A name from `preview <host>` (`label` = "host") or `specs --host`
/// (`label` = "--host"): no lowercasing, uppercase is an error.
pub fn given_host_name(name: &str, label: &str) -> Result<(String, Option<String>), Error> {
    if name.chars().any(|c| c.is_ascii_uppercase()) {
        return Err(Error::failed(format!(
            "{label} \"{name}\" has uppercase; host names are lowercase"
        )));
    }
    check_host_name(name)?;
    let warning = (!is_rfc1123(name)).then(|| {
        format!("{label} \"{name}\" is not a valid hostname (only a-z, 0-9, '-' and '.')")
    });
    Ok((name.to_string(), warning))
}

/// The part of ADR 0070 that keeps the name inside `hosts/`: it becomes a file
/// name, so `..` or a separator would point somewhere else.
pub fn check_host_name(name: &str) -> Result<(), Error> {
    if name.is_empty() || name == "." || name == ".." || name.contains(['/', '\\']) {
        return Err(Error::failed(format!("unsafe host name \"{name}\"")));
    }
    Ok(())
}

/// RFC 1123: `a`-`z`, `0`-`9`, `-`; labels of 1-63 characters separated by
/// `.`, no `-` at a label's start or end; at most 253 characters.
pub fn is_rfc1123(name: &str) -> bool {
    name.len() <= 253
        && name.split('.').all(|label| {
            !label.is_empty()
                && label.len() <= 63
                && !label.starts_with('-')
                && !label.ends_with('-')
                && label.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
        })
}

/// One warning per file in `hosts/` whose name can never match or breaks the
/// format (ADR 0070). Shown on every run that picks a host file.
pub fn host_file_warnings(repo: &Path) -> Vec<String> {
    let mut names: Vec<String> = std::fs::read_dir(repo.join("hosts"))
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| e.file_name().into_string().ok())
        .collect();
    names.sort();

    let mut warnings = Vec::new();
    for file in names {
        let Some(stem) = file.strip_suffix(".lua") else { continue };
        if stem.chars().any(|c| c.is_ascii_uppercase()) {
            warnings.push(format!(
                "hosts/{file}: host file names must be lowercase; this file is never used"
            ));
        } else if !is_rfc1123(stem) {
            warnings.push(format!(
                "hosts/{file}: \"{stem}\" is not a valid hostname (only a-z, 0-9, '-' and '.')"
            ));
        }
    }
    warnings
}

#[cfg(target_os = "linux")]
fn read_os_hostname() -> Option<String> {
    // The same value gethostname() returns, without needing libc.
    std::fs::read_to_string("/proc/sys/kernel/hostname").ok()
}

/// macOS: LocalHostName (Settings > General > Sharing > Local hostname).
#[cfg(target_os = "macos")]
fn read_os_hostname() -> Option<String> {
    command_output("scutil", &["--get", "LocalHostName"])
}

/// Windows: `hostname.exe` prints the DNS host name (not the NetBIOS name).
#[cfg(windows)]
fn read_os_hostname() -> Option<String> {
    command_output("hostname", &[])
}

/// Other Unix (BSDs, Android outside Linux builds): `hostname`.
#[cfg(not(any(target_os = "linux", target_os = "macos", windows)))]
fn read_os_hostname() -> Option<String> {
    command_output("hostname", &[])
}

#[cfg(not(target_os = "linux"))]
fn command_output(program: &str, args: &[&str]) -> Option<String> {
    let out = std::process::Command::new(program).args(args).output().ok()?;
    if !out.status.success() {
        return None;
    }
    String::from_utf8(out.stdout).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rfc1123() {
        for ok in ["laptop", "nexos.lan", "a-b", "x1", "a.b.c"] {
            assert!(is_rfc1123(ok), "{ok}");
        }
        for bad in ["my_box", "-a", "a-", "a..b", "", ".a", &"a".repeat(64)] {
            assert!(!is_rfc1123(bad), "{bad}");
        }
    }

    #[test]
    fn given_names() {
        assert!(given_host_name("Laptop", "host").is_err());
        assert!(given_host_name("..", "host").is_err());
        let (_, w) = given_host_name("my_box", "--host").unwrap();
        assert_eq!(
            w.unwrap(),
            "--host \"my_box\" is not a valid hostname (only a-z, 0-9, '-' and '.')"
        );
    }
}
