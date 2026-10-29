//! The state directory, `state.json` and the run lock (design.typ "State and
//! generations", ADR 0060, 0062, 0063, 0075, 0077, 0084).
//!
//! State is "what mdot deployed last time": the *recorded* side of the 3-way
//! diff. It is loaded once per run and saved after every apply step.

use crate::error::Error;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs::{self, File, OpenOptions, TryLockError};
use std::io::{ErrorKind, Write};
use std::path::{Path, PathBuf};

/// The `version` this mdot reads and writes. Every format change bumps it and
/// ships a migration from the one before (ADR 0075).
pub const VERSION: u64 = 1;

/// `state.json`. `Serialize`/`Deserialize` are derived: serde generates the
/// JSON code from the field names, so the struct *is* the file format.
/// `deny_unknown_fields` turns a field this mdot doesn't know into an error.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct State {
    pub version: u64,
    /// Absent until the first apply stores it (ADR 0062).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub repo: Option<PathBuf>,
    /// Directories mdot created for a `dst` parent (ADR 0060).
    pub created_dirs: Vec<PathBuf>,
    pub resources: Vec<Record>,
}

/// One deployed resource. `tag = "kind"` stores the variant name inside the
/// object: `{ "kind": "link", "spec": ..., "src": ..., "dst": ... }`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Record {
    Link(LinkRecord),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LinkRecord {
    /// The owning spec; never compared by the planner (ADR 0055).
    pub spec: String,
    /// Absolute, lexically normal (ADR 0056).
    pub src: PathBuf,
    pub dst: PathBuf,
}

impl Record {
    /// The resource ID, computed, never stored (ADR 0054).
    pub fn id(&self) -> String {
        match self {
            Record::Link(l) => link_id(&l.dst),
        }
    }
}

pub fn link_id(dst: &Path) -> String {
    format!("link:{}", dst.display())
}

impl State {
    pub fn empty() -> State {
        State { version: VERSION, repo: None, created_dirs: Vec::new(), resources: Vec::new() }
    }

    /// Every link record, in file order.
    pub fn links(&self) -> impl Iterator<Item = &LinkRecord> {
        self.resources.iter().map(|r| match r {
            Record::Link(l) => l,
        })
    }

    /// Replaces the record with this ID, or appends it.
    pub fn put(&mut self, record: Record) {
        let id = record.id();
        match self.resources.iter_mut().find(|r| r.id() == id) {
            Some(slot) => *slot = record,
            None => self.resources.push(record),
        }
    }

    pub fn remove(&mut self, id: &str) {
        self.resources.retain(|r| r.id() != id);
    }
}

/// `<base>/mdot-data`, where base is XDG_STATE_HOME if it is set and absolute,
/// else ~/.local/state (Linux, macOS) or AppData\Local (Windows) (ADR 0077).
pub fn state_dir() -> Result<PathBuf, Error> {
    if let Some(xdg) = std::env::var_os("XDG_STATE_HOME") {
        let xdg = PathBuf::from(xdg);
        if xdg.is_absolute() {
            return Ok(xdg.join("mdot-data"));
        }
    }
    let base = if cfg!(windows) {
        dirs::data_local_dir()
            .ok_or_else(|| Error::failed("cannot find the state directory: no AppData\\Local"))?
    } else {
        dirs::home_dir()
            .ok_or_else(|| Error::failed("cannot find the state directory: no home directory"))?
            .join(".local/state")
    };
    Ok(base.join("mdot-data"))
}

/// Reads `<dir>/state.json`. A missing file is empty state.
pub fn load(dir: &Path) -> Result<State, Error> {
    let path = dir.join("state.json");
    let fail = |msg: String| Error::failed(format!("{}: {msg}", path.display()));
    let text = match fs::read_to_string(&path) {
        Ok(t) => t,
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(State::empty()),
        Err(e) => return Err(fail(e.to_string())),
    };

    // Read `version` first: a newer file may have fields this mdot can't parse.
    let value: serde_json::Value =
        serde_json::from_str(&text).map_err(|e| fail(format!("not valid JSON: {e}")))?;
    let version = value
        .get("version")
        .and_then(|v| v.as_u64())
        .ok_or_else(|| fail("no version".to_string()))?;
    if version > VERSION {
        return Err(fail(format!(
            "version {version} is newer than this mdot knows ({VERSION}); upgrade mdot"
        )));
    }
    if version < VERSION {
        // No older format exists yet. Before the first release a bump may skip
        // the migration (ADR 0075); after it, migrate the Value here.
        return Err(fail(format!(
            "version {version} is too old; delete state.json and run `mdot apply` again"
        )));
    }

    let state: State =
        serde_json::from_value(value).map_err(|e| fail(e.to_string()))?;

    let mut seen = HashSet::new();
    for record in &state.resources {
        if !seen.insert(record.id()) {
            return Err(fail(format!("two records for {}", record.id())));
        }
    }
    Ok(state)
}

/// Writes `<dir>/state.json` atomically: a temp file next to it, flushed to
/// disk, then renamed over the old one. A crash leaves the old or the new
/// file, never half of one.
pub fn save(dir: &Path, state: &State) -> Result<(), Error> {
    let path = dir.join("state.json");
    let tmp = dir.join("state.json.tmp");
    let fail = |e: std::io::Error| Error::failed(format!("cannot write {}: {e}", path.display()));

    let mut json = serde_json::to_string_pretty(state)
        .map_err(|e| Error::failed(format!("cannot encode state: {e}")))?;
    json.push('\n');

    let mut file = File::create(&tmp).map_err(fail)?;
    file.write_all(json.as_bytes()).map_err(fail)?;
    file.sync_all().map_err(fail)?;
    fs::rename(&tmp, &path).map_err(fail)?;
    Ok(())
}

/// Holds the run lock. The OS releases it when the file is closed, which
/// happens when this value is dropped or the process exits, even on a crash.
#[derive(Debug)]
pub struct Lock {
    _file: Option<File>,
}

fn busy(dir: &Path) -> Error {
    Error::refused(format!(
        "another mdot run is using {}; try again when it finishes",
        dir.display()
    ))
}

/// `plan`: a shared lock, never creating anything (ADR 0084). Without a lock
/// file (nothing applied yet) it runs without a lock.
pub fn lock_shared(dir: &Path) -> Result<Lock, Error> {
    let path = dir.join("lock");
    let file = match File::open(&path) {
        Ok(f) => f,
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(Lock { _file: None }),
        Err(e) => return Err(Error::failed(format!("{}: {e}", path.display()))),
    };
    match file.try_lock_shared() {
        Ok(()) => Ok(Lock { _file: Some(file) }),
        Err(TryLockError::WouldBlock) => Err(busy(dir)),
        Err(TryLockError::Error(e)) => Err(Error::failed(format!("{}: {e}", path.display()))),
    }
}

/// `apply`: an exclusive lock, creating the state directory and lock file
/// when missing. The lock file is never deleted.
pub fn lock_exclusive(dir: &Path) -> Result<Lock, Error> {
    let path = dir.join("lock");
    fs::create_dir_all(dir).map_err(|e| Error::failed(format!("{}: {e}", dir.display())))?;
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(&path)
        .map_err(|e| Error::failed(format!("{}: {e}", path.display())))?;
    match file.try_lock() {
        Ok(()) => Ok(Lock { _file: Some(file) }),
        Err(TryLockError::WouldBlock) => Err(busy(dir)),
        Err(TryLockError::Error(e)) => Err(Error::failed(format!("{}: {e}", path.display()))),
    }
}
