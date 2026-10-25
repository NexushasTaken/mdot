use std::fs;
use std::io;
use std::path::{Component, Path, PathBuf};

// C++ `path::lexically_normal()`. Rust's std has no equivalent: `Path::components()`
// already drops `.` and duplicate/trailing slashes, but leaves `..` alone (resolving
// `..` lexically is wrong when a symlink is involved, so std refuses to guess).
pub fn lexically_normal(path: &Path) -> PathBuf {
    if path.as_os_str().is_empty() {
        return PathBuf::new();
    }

    let mut out = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => match out.components().next_back() {
                Some(Component::Normal(_)) => {
                    out.pop();
                }
                // `/..` is `/`.
                Some(Component::RootDir) | Some(Component::Prefix(_)) => {}
                // Leading `..` of a relative path is kept.
                _ => out.push(".."),
            },
            other => out.push(other.as_os_str()),
        }
    }

    if out.as_os_str().is_empty() {
        out.push(".");
    }
    out
}

// C++ `clean_path` strips the empty filename a trailing slash leaves behind
// ("/a/b/" -> "/a/b"). In Rust a `PathBuf` built from components never keeps a
// trailing slash, and `Path == Path` compares components, so "/a/b/" == "/a/b".
// That makes `clean_path` the same as `lexically_normal` here.
pub fn clean_path(path: &Path) -> PathBuf {
    lexically_normal(path)
}

pub fn normalize_path(path: &Path) -> Result<PathBuf, String> {
    if path.is_relative() {
        let current_path = std::env::current_dir().map_err(|e| e.to_string())?;
        return Ok(clean_path(&current_path.join(path)));
    }
    Ok(clean_path(path))
}

pub fn expand_home(path: &Path) -> Result<PathBuf, String> {
    if path.as_os_str().is_empty() {
        return Ok(path.to_path_buf());
    }

    // C++: `*path.begin() == "~"` then `path.lexically_relative("~")`.
    match path.strip_prefix("~") {
        Ok(rest) => {
            let home = dirs::home_dir().ok_or("unable to find the home directory")?;
            Ok(home.join(rest))
        }
        Err(_) => Ok(path.to_path_buf()),
    }
}

// C++: `expand_home(path).and_then(normalize_path)`. Same shape in Rust.
pub fn resolve_path(path: &Path) -> Result<PathBuf, String> {
    expand_home(path).and_then(|p| normalize_path(&p))
}

pub fn read_file(path: &Path) -> Result<String, String> {
    let path_st =
        fs::symlink_metadata(path).map_err(|e| format!("{}: {}", path.display(), e))?;

    if !path_st.file_type().is_file() {
        return Err(format!("{}: is not a regular file", path.display()));
    }

    fs::read_to_string(path).map_err(|e| format!("{}: {}", path.display(), e))
}

// C++ `fs::create_symlink` is one call on every platform. Rust exposes the OS
// difference: Unix has one `symlink`, Windows needs to know file vs directory.
#[cfg(unix)]
pub fn create_symlink(target: &Path, link: &Path) -> io::Result<()> {
    std::os::unix::fs::symlink(target, link)
}

#[cfg(windows)]
pub fn create_symlink(target: &Path, link: &Path) -> io::Result<()> {
    if target.is_dir() {
        std::os::windows::fs::symlink_dir(target, link)
    } else {
        std::os::windows::fs::symlink_file(target, link)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lexically_normal_matches_std_filesystem() {
        let cases = [
            ("/a/./b/../c/", "/a/c"),
            ("a/..", "."),
            ("../a", "../a"),
            ("/..", "/"),
            ("/a//b", "/a/b"),
            ("", ""),
        ];
        for (input, expected) in cases {
            assert_eq!(lexically_normal(Path::new(input)), Path::new(expected), "{input}");
        }
    }
}
