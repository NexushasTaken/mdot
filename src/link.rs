use crate::common::clean_path;
use crate::error::LinkError;
use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

// C++ has `enum PlanOperation` plus a struct whose fields are only meaningful for
// some operations (`m_message` is empty for Create, `m_dst` is empty for Conflict).
// A Rust enum carries the data inside each variant, so a Noop simply has no paths
// and a Conflict can't be missing its message. This is `std::variant` built into
// the language, and `match` forces you to handle every variant.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LinkPlan {
    Create { src: PathBuf, dst: PathBuf },
    Noop,
    // C++ `make_conflict` stores this path in `m_src`, even though it's usually dst.
    Conflict { path: PathBuf, message: String },
}

impl LinkPlan {
    pub fn is_create(&self) -> bool {
        matches!(self, LinkPlan::Create { .. })
    }
    pub fn is_noop(&self) -> bool {
        matches!(self, LinkPlan::Noop)
    }
    pub fn is_conflict(&self) -> bool {
        matches!(self, LinkPlan::Conflict { .. })
    }

    fn conflict(path: impl Into<PathBuf>, message: impl Into<String>) -> Self {
        LinkPlan::Conflict {
            path: path.into(),
            message: message.into(),
        }
    }
}

// FIX: can't handle permissions yet.
pub fn plan_link(src: &Path, dst: &Path) -> Result<LinkPlan, LinkError> {
    if src.is_relative() {
        return Err(LinkError::new(src, "must be absolute path"));
    }
    if dst.is_relative() {
        return Err(LinkError::new(dst, "must be absolute path"));
    }

    // C++ `fs::exists(src, ec)` returns a bool and sets `ec` on the side.
    // Rust folds both into one `Result<bool>`, so there are three cases to match.
    match src.try_exists() {
        Ok(true) => {}
        Ok(false) => return Err(LinkError::new(src, "No such file or directory")),
        Err(e) => return Err(LinkError::from_io(src, &e)),
    }

    {
        let mut path = PathBuf::new();

        for segment in dst.components() {
            path.push(segment);
            if path == dst {
                break;
            }

            // TODO: while path < normalized_dst - if the ancestor is a dangling
            // link, allow the user to specify, if that should be an error or
            // warning.
            //
            // `fs::metadata` follows symlinks, like C++ `fs::status`.
            match fs::metadata(&path) {
                Err(e) if e.kind() == ErrorKind::NotFound => break,
                Err(e) => return Err(LinkError::from_io(&path, &e)),
                Ok(path_st) if !path_st.is_dir() => {
                    return Ok(LinkPlan::conflict(path, "Is not a directory"));
                }
                Ok(_) => {}
            }
        }
    }

    // `fs::symlink_metadata` does not follow symlinks, like C++ `fs::symlink_status`.
    let dst_st = match fs::symlink_metadata(dst) {
        Err(e) if e.kind() == ErrorKind::NotFound => {
            return Ok(LinkPlan::Create {
                src: src.to_path_buf(),
                dst: dst.to_path_buf(),
            });
        }
        Err(e) => return Err(LinkError::from_io(dst, &e)),
        Ok(st) => st,
    };

    if !dst_st.file_type().is_symlink() {
        return Ok(LinkPlan::conflict(dst, "Is not a symlink"));
    }

    // `?` is the early return: on Err it returns the (mapped) error, on Ok it unwraps.
    let link_target = fs::read_link(dst).map_err(|e| LinkError::from_io(dst, &e))?;
    // An absolute dst always has a parent; `/` is only a fallback for dst == "/".
    let dst_parent = dst.parent().unwrap_or(Path::new("/"));
    let dst_target = clean_path(&dst_parent.join(link_target));

    if dst_target == src {
        Ok(LinkPlan::Noop)
    } else {
        Ok(LinkPlan::conflict(dst, "Symlinked to different file"))
    }
}
