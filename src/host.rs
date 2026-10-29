//! Which host file to load (ADR 0070, 0071, 0079).

use crate::error::Error;

/// The real hostname, lowercased (ASCII only), checked by `check_host_name`.
pub fn real_hostname() -> Result<String, Error> {
    let raw = read_os_hostname()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| Error::failed("cannot determine the hostname; set one"))?;
    let name = raw.to_ascii_lowercase();
    check_host_name(&name)?;
    // TODO(build): ADR 0079 warning when `name` breaks RFC 1123 (once per run).
    Ok(name)
}

/// A name from `preview <host>` or `specs --host`: no lowercasing, uppercase
/// is an error (ADR 0079).
pub fn given_host_name(name: &str) -> Result<String, Error> {
    if name.chars().any(|c| c.is_ascii_uppercase()) {
        return Err(Error::failed(format!(
            "host name \"{name}\" has uppercase; host names are lowercase"
        )));
    }
    check_host_name(name)?;
    Ok(name.to_string())
}

/// The part of ADR 0079 that keeps the name inside `hosts/`: it becomes a file
/// name, so `..` or a separator would point somewhere else.
pub fn check_host_name(name: &str) -> Result<(), Error> {
    if name.is_empty() || name == "." || name == ".." || name.contains(['/', '\\']) {
        return Err(Error::failed(format!("unsafe host name \"{name}\"")));
    }
    Ok(())
}

#[cfg(target_os = "linux")]
fn read_os_hostname() -> Option<String> {
    // The same value gethostname() returns, without needing libc.
    std::fs::read_to_string("/proc/sys/kernel/hostname").ok()
}

#[cfg(not(target_os = "linux"))]
fn read_os_hostname() -> Option<String> {
    // TODO(build): macOS LocalHostName, Windows DNS hostname (ADR 0070).
    todo!("build: hostname on this OS (ADR 0070)")
}
