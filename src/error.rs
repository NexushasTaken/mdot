use std::fmt;
use std::io;
use std::path::{Path, PathBuf};

// C++: `static tl::unexpected<LinkError> make_error(...)`.
// Rust has no `tl::unexpected` wrapper: you return `Err(LinkError::new(...))`,
// and `Result<T, E>` is built into the language.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinkError {
    pub path: PathBuf,
    pub message: String,
}

impl LinkError {
    pub fn new(path: impl Into<PathBuf>, message: impl Into<String>) -> Self {
        LinkError {
            path: path.into(),
            message: message.into(),
        }
    }

    // C++ overload `make_error(path, std::error_code)`. Rust has no overloading,
    // so the second constructor gets its own name.
    pub fn from_io(path: impl Into<PathBuf>, err: &io::Error) -> Self {
        LinkError::new(path, err.to_string())
    }

    pub fn path(&self) -> &Path {
        &self.path
    }
}

// C++: `std::string string() const`. Implementing `Display` gives you
// `format!("{err}")` and `err.to_string()` for free.
impl fmt::Display for LinkError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.path.display(), self.message)
    }
}

impl std::error::Error for LinkError {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClauseError {
    pub id: usize,
    pub message: String,
}

impl ClauseError {
    pub fn new(id: usize, message: impl Into<String>) -> Self {
        ClauseError {
            id,
            message: message.into(),
        }
    }
}

impl fmt::Display for ClauseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "entry {}: {}", self.id, self.message)
    }
}

impl std::error::Error for ClauseError {}
