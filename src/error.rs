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

// ---------------------------------------------------------------------------
// Run errors (ADR 0053). Everything above is the prototype's per-link error;
// everything below is what the loader, planner and apply report to the user.

/// Which exit code an error gives. The numbers are the process exit codes.
/// `Ord` follows the declaration order, so `max()` picks `Failed` when both
/// happen ("2 wins over 1").
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Code {
    /// 1: mdot finished its checks and a rule says no (conflict, `src` outside
    /// its spec, a `depends` cycle, two specs with one `dst`).
    Refused = 1,
    /// 2: mdot could not finish (unreadable file, Lua error, missing name,
    /// missing `src`, failed write).
    Failed = 2,
}

/// One user-facing error. `message` has no `error:` prefix; the output code
/// adds it (ADR 0050).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Error {
    pub code: Code,
    pub message: String,
}

impl Error {
    pub fn refused(message: impl Into<String>) -> Self {
        Error { code: Code::Refused, message: message.into() }
    }
    pub fn failed(message: impl Into<String>) -> Self {
        Error { code: Code::Failed, message: message.into() }
    }
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for Error {}

/// The exit code for a list of errors: 0 if empty, else the highest code.
pub fn exit_code(errors: &[Error]) -> u8 {
    errors.iter().map(|e| e.code as u8).max().unwrap_or(0)
}
