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
