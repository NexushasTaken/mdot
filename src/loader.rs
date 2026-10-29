//! Loading a repo (design.typ "Loading and sandbox", "Hosts and selection",
//! `file.link()`): config.lua, then the host file, then every spec the host
//! reaches through `depends`, in dependency order (ADR 0066).
//!
//! Loading reports every error it finds instead of stopping at the first one
//! (ADR 0021), so `load` returns what it managed to load *and* the errors.

use crate::common::lexically_normal;
use crate::error::Error;
use crate::facts::Facts;
use crate::sandbox::{Clause, Role, Sandbox};
use std::collections::HashMap;
use std::fs;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};

/// One link a spec asks for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DesiredLink {
    /// The owning spec's name (ADR 0055).
    pub spec: String,
    /// Absolute and lexically normal (ADR 0056): what is stored and linked.
    pub src: PathBuf,
    pub dst: PathBuf,
    /// As written in the spec, for output (ADR 0051).
    pub src_shown: String,
    pub dst_shown: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    /// No spec.lua: the directory is linked to ~/.config/<name>.
    Implicit,
    /// spec.lua decides everything.
    Explicit,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LoadedSpec {
    pub name: String,
    pub dir: PathBuf,
    pub mode: Mode,
    /// Names as written in `depends`, in order (missing ones included).
    pub depends: Vec<String>,
    pub links: Vec<DesiredLink>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Loaded {
    pub repo: PathBuf,
    pub host: String,
    pub host_depends: Vec<String>,
    /// Every spec reached, in dependency order (ADR 0066). This is the SpecSet.
    pub specs: Vec<LoadedSpec>,
    /// Directories in specs/ the host does not reach, sorted.
    pub not_reached: Vec<String>,
}

impl Loaded {
    pub fn spec(&self, name: &str) -> Option<&LoadedSpec> {
        self.specs.iter().find(|s| s.name == name)
    }

    /// Every desired link, spec by spec in dependency order, each spec's links
    /// in the order it declares them.
    pub fn links(&self) -> impl Iterator<Item = &DesiredLink> {
        self.specs.iter().flat_map(|s| s.links.iter())
    }
}

/// What `load` returns: everything that loaded, plus every error found. The
/// run may only plan or apply when `errors` is empty.
#[derive(Debug, Default)]
pub struct LoadResult {
    pub loaded: Loaded,
    pub errors: Vec<Error>,
}

/// The repo root: `--repo <dir>`, else the current directory if it has
/// `specs/`, else an error. The result is absolute and lexically normal.
pub fn find_repo(flag: Option<&Path>) -> Result<PathBuf, Error> {
    let cwd = std::env::current_dir()
        .map_err(|e| Error::failed(format!("cannot read the current directory: {e}")))?;
    match flag {
        Some(dir) => {
            let repo = lexically_normal(&cwd.join(dir));
            if !repo.join("specs").is_dir() {
                return Err(Error::failed(format!("{}: not a repo (no specs/)", repo.display())));
            }
            Ok(repo)
        }
        None if cwd.join("specs").is_dir() => Ok(lexically_normal(&cwd)),
        None => Err(Error::failed(
            "no repo here: run mdot in a directory with specs/, or pass --repo <dir>",
        )),
    }
}

/// Loads `repo` for the host named in `facts.os.hostname`.
pub fn load(repo: &Path, facts: &Facts) -> LoadResult {
    let mut result = LoadResult::default();
    result.loaded.repo = repo.to_path_buf();
    result.loaded.host = facts.os.hostname.clone();

    let home = match facts.dirs.iter().find(|(n, _)| *n == "home") {
        Some((_, Some(h))) => PathBuf::from(h),
        _ => {
            result.errors.push(Error::failed("cannot find the home directory"));
            return result;
        }
    };

    let known = match list_spec_dirs(repo) {
        Ok(k) => k,
        Err(e) => {
            result.errors.push(e);
            return result;
        }
    };

    let sandbox = match Sandbox::new(facts) {
        Ok(s) => s,
        Err(e) => {
            result.errors.push(e);
            return result;
        }
    };

    // 1. config.lua, if any. It only sets base mdot.vars (ADR 0038).
    let config = repo.join("config.lua");
    if config.exists() {
        match read(&config).and_then(|code| sandbox.run(Role::Config, "config.lua", &code)) {
            Ok(mlua::Value::Nil) => {}
            Ok(_) => result
                .errors
                .push(Error::failed("config.lua: must not return a value; it only sets mdot.vars")),
            Err(e) => {
                // Without base vars, the host and specs would load against the
                // wrong values: stop here.
                result.errors.push(e);
                return result;
            }
        }
    }
    // TODO(build): ADR 0039 vars schema: a function in base vars is an error;
    // check the host's overrides against base after step 2.

    // 2. The host file: selection and vars overrides only.
    let host = &facts.os.hostname;
    let host_rel = format!("hosts/{host}.lua");
    let host_path = repo.join(&host_rel);
    if !host_path.is_file() {
        result.errors.push(Error::failed(format!(
            "{host_rel} does not exist; hosts/ has: {}",
            list_or_none(&list_host_files(repo))
        )));
        return result;
    }
    let host_clauses = read(&host_path)
        .and_then(|code| sandbox.run(Role::Host, &host_rel, &code))
        .and_then(|value| sandbox.clauses(&host_rel, value));
    let host_clauses = match host_clauses {
        Ok(c) => c,
        Err(e) => {
            result.errors.push(e);
            return result;
        }
    };
    for clause in host_clauses {
        match clause {
            Clause::Depends(names) => result.loaded.host_depends.extend(names),
            Clause::Link { .. } => result.errors.push(Error::refused(format!(
                "{host_rel}: file.link is not allowed in a host file; put it in a spec"
            ))),
        }
    }

    // 3. Every spec the host reaches, depth first.
    let mut walk = Walk {
        repo,
        home: &home,
        sandbox: &sandbox,
        known: &known,
        visits: HashMap::new(),
        stack: Vec::new(),
        out: Vec::new(),
        errors: Vec::new(),
    };
    for name in result.loaded.host_depends.clone() {
        walk.visit(&name, &host_rel);
    }
    result.loaded.specs = walk.out;
    result.errors.append(&mut walk.errors);

    result.loaded.not_reached = known
        .iter()
        .filter(|n| result.loaded.spec(n).is_none())
        .cloned()
        .collect();

    // 4. Two links with the same dst (ADR 0021): one error per extra claim.
    let mut owners: HashMap<&Path, &DesiredLink> = HashMap::new();
    for link in result.loaded.links() {
        if let Some(first) = owners.get(link.dst.as_path()) {
            result.errors.push(Error::refused(format!(
                "{}: dst of both {} and {}",
                link.dst_shown, first.spec, link.spec
            )));
        } else {
            owners.insert(&link.dst, link);
        }
    }

    result
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Visit {
    /// On the current depends path; meeting it again is a cycle.
    InProgress,
    Done,
}

/// The state of the depth-first walk over `depends`. A struct instead of many
/// function arguments; `'a` says it only borrows what `load` owns.
struct Walk<'a> {
    repo: &'a Path,
    home: &'a Path,
    sandbox: &'a Sandbox,
    known: &'a [String],
    visits: HashMap<String, Visit>,
    /// The current path, for naming a cycle.
    stack: Vec<String>,
    out: Vec<LoadedSpec>,
    errors: Vec<Error>,
}

impl Walk<'_> {
    /// Post-order DFS: a spec is appended after all its deps, so with
    /// laptop -> (wm, term), wm -> (hypr, fonts), term -> (fonts, foot) the
    /// order is hypr, fonts, wm, foot, term (ADR 0066).
    fn visit(&mut self, name: &str, from: &str) {
        match self.visits.get(name) {
            Some(Visit::Done) => return,
            Some(Visit::InProgress) => {
                let start = self.stack.iter().position(|n| n == name).unwrap_or(0);
                let mut cycle = self.stack[start..].to_vec();
                cycle.push(name.to_string());
                self.errors.push(Error::refused(format!("depends cycle: {}", cycle.join(" -> "))));
                return;
            }
            None => {}
        }
        if !self.known.iter().any(|k| k == name) {
            self.errors.push(Error::failed(format!(
                "{from}: unknown spec \"{name}\" in depends; specs/ has: {}",
                list_or_none(self.known)
            )));
            // Remember it, so each unknown name is reported once.
            self.visits.insert(name.to_string(), Visit::Done);
            return;
        }

        self.visits.insert(name.to_string(), Visit::InProgress);
        let spec = match self.load_spec(name) {
            Ok(s) => s,
            Err(mut errs) => {
                self.errors.append(&mut errs);
                self.visits.insert(name.to_string(), Visit::Done);
                return;
            }
        };

        self.stack.push(name.to_string());
        let rel = format!("specs/{name}/spec.lua");
        for dep in &spec.depends {
            self.visit(dep, &rel);
        }
        self.stack.pop();

        self.visits.insert(name.to_string(), Visit::Done);
        self.out.push(spec);
    }

    /// Runs one spec (or builds its implicit link). Several errors can come
    /// back, one per bad link.
    fn load_spec(&self, name: &str) -> Result<LoadedSpec, Vec<Error>> {
        let dir = self.repo.join("specs").join(name);
        let file = dir.join("spec.lua");

        if !file.exists() {
            // Implicit spec (ADR 0020): the whole directory to ~/.config/<name>.
            let dst_shown = format!("~/.config/{name}");
            let dst = expand_dst(&dst_shown, self.home).map_err(|e| vec![e])?;
            let link = DesiredLink {
                spec: name.to_string(),
                src: dir.clone(),
                dst,
                src_shown: ".".to_string(),
                dst_shown,
            };
            return Ok(LoadedSpec {
                name: name.to_string(),
                dir,
                mode: Mode::Implicit,
                depends: Vec::new(),
                links: vec![link],
            });
        }

        let rel = format!("specs/{name}/spec.lua");
        let clauses = read(&file)
            .and_then(|code| self.sandbox.run(Role::Spec, &rel, &code))
            .and_then(|value| self.sandbox.clauses(&rel, value))
            .map_err(|e| vec![e])?;
        if clauses.is_empty() {
            return Err(vec![Error::refused(format!("{rel}: declares nothing"))]);
        }

        let mut spec = LoadedSpec {
            name: name.to_string(),
            dir: dir.clone(),
            mode: Mode::Explicit,
            depends: Vec::new(),
            links: Vec::new(),
        };
        let mut errors = Vec::new();
        for clause in clauses {
            match clause {
                Clause::Depends(names) => spec.depends.extend(names),
                Clause::Link { src, dst } => {
                    let src_abs = check_src(name, &dir, &src);
                    let dst_abs = expand_dst(&dst, self.home)
                        .map_err(|e| Error { message: format!("{name}: {}", e.message), ..e });
                    match (src_abs, dst_abs) {
                        (Ok(src_abs), Ok(dst_abs)) => spec.links.push(DesiredLink {
                            spec: name.to_string(),
                            src: src_abs,
                            dst: dst_abs,
                            src_shown: src,
                            dst_shown: dst,
                        }),
                        (a, b) => errors.extend(a.err().into_iter().chain(b.err())),
                    }
                }
            }
        }
        if errors.is_empty() { Ok(spec) } else { Err(errors) }
    }
}

/// `dst` or `into` as written -> absolute, lexically normal path (ADR 0020,
/// 0056). Only a leading `~` is expanded; a `$` anywhere is an error.
pub fn expand_dst(dst: &str, home: &Path) -> Result<PathBuf, Error> {
    if dst.contains('$') {
        return Err(Error::failed(format!(
            "dst \"{dst}\" contains $; only a leading ~ is expanded"
        )));
    }
    let path = if dst == "~" {
        home.to_path_buf()
    } else if let Some(rest) = dst.strip_prefix("~/").or_else(|| dst.strip_prefix("~\\")) {
        home.join(rest)
    } else {
        PathBuf::from(dst)
    };
    if !path.is_absolute() {
        // TODO(design): not in design.typ; a relative dst has no base to be
        // relative to, so it is refused here.
        return Err(Error::failed(format!("dst \"{dst}\" must start with ~/ or be absolute")));
    }
    Ok(lexically_normal(&path))
}

/// The `src` checks, in ADR 0081's order: it must exist (exit 2), then it must
/// resolve inside its own spec directory (ADR 0080, exit 1). Returns the
/// lexical path, which is what gets stored and linked.
pub fn check_src(spec: &str, dir: &Path, src: &str) -> Result<PathBuf, Error> {
    let norm = lexically_normal(&dir.join(src));
    let missing = |extra: String| {
        Error::failed(format!("{spec}: src \"{src}\" does not exist{extra}"))
    };

    // symlink_metadata looks at the path itself; metadata follows a symlink.
    match fs::symlink_metadata(&norm) {
        Err(_) => return Err(missing(String::new())),
        Ok(m) if m.file_type().is_symlink() => {
            if let Err(e) = fs::metadata(&norm) {
                if e.kind() == ErrorKind::NotFound {
                    let target = fs::read_link(&norm).unwrap_or_default();
                    return Err(missing(format!(" (symlink target missing: {})", target.display())));
                }
                return Err(missing(String::new()));
            }
        }
        Ok(_) => {}
    }

    let real_spec = fs::canonicalize(dir)
        .map_err(|e| Error::failed(format!("{}: {e}", dir.display())))?;
    let real_src = fs::canonicalize(&norm)
        .map_err(|e| Error::failed(format!("{}: {e}", norm.display())))?;
    // Path::starts_with compares whole components: specs/foo is not a prefix
    // of specs/foobar/x. A path also starts with itself, so "." is inside.
    if !real_src.starts_with(&real_spec) {
        // Lexically inside but resolved outside: a symlink did it, so say where.
        let because = if norm.starts_with(dir) {
            format!(" (resolves to {})", real_src.display())
        } else {
            String::new()
        };
        return Err(Error::refused(format!(
            "{spec}: src \"{src}\" is outside specs/{spec}/{because}"
        )));
    }
    Ok(norm)
}

/// Directory names in specs/, sorted, so lists in errors are stable.
fn list_spec_dirs(repo: &Path) -> Result<Vec<String>, Error> {
    let specs = repo.join("specs");
    let entries =
        fs::read_dir(&specs).map_err(|e| Error::failed(format!("{}: {e}", specs.display())))?;
    let mut names = Vec::new();
    for entry in entries {
        let entry = entry.map_err(|e| Error::failed(format!("{}: {e}", specs.display())))?;
        // is_dir() follows symlinks, so a symlinked spec directory counts.
        if !entry.path().is_dir() {
            continue;
        }
        match entry.file_name().into_string() {
            Ok(name) => names.push(name),
            Err(raw) => {
                return Err(Error::failed(format!(
                    "specs/{}: spec names must be valid UTF-8",
                    raw.to_string_lossy()
                )))
            }
        }
    }
    names.sort();
    Ok(names)
}

/// File names in hosts/, sorted (for the "missing host file" error).
fn list_host_files(repo: &Path) -> Vec<String> {
    let mut names: Vec<String> = fs::read_dir(repo.join("hosts"))
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| e.file_name().into_string().ok())
        .collect();
    names.sort();
    names
}

fn list_or_none(names: &[String]) -> String {
    if names.is_empty() { "none".to_string() } else { names.join(", ") }
}

fn read(path: &Path) -> Result<String, Error> {
    fs::read_to_string(path).map_err(|e| Error::failed(format!("{}: {e}", path.display())))
}
