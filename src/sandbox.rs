//! Runs user Lua files (config.lua, host files, spec.lua) in the sandbox and
//! turns what a file returns into `Clause`s.
//!
//! The sandbox itself is written in Lua (`sandbox.lua`), because "a table whose
//! writes fail" is easiest to say in Lua. This file does the Rust side: create
//! the Lua state, hand the machine facts to `sandbox.lua`, run each file in the
//! fresh environment it builds, and read the result.

use crate::error::Error;
use crate::facts::{Facts, DIR_NAMES};
use mlua::{ChunkMode, Function, Lua, LuaOptions, StdLib, Table, Value};
use std::io::Write;

/// What a clause call produced, as plain Rust data.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Clause {
    /// `file.link(src, dst)`, or one name of the batch form. Both strings are as
    /// written; the loader expands and checks them.
    Link { src: String, dst: String },
    /// `depends(names...)`.
    Depends(Vec<String>),
}

/// Which kind of file is running. It decides what `mdot.vars` allows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Role {
    Config,
    Host,
    Spec,
}

impl Role {
    fn as_str(self) -> &'static str {
        match self {
            Role::Config => "config",
            Role::Host => "host",
            Role::Spec => "spec",
        }
    }
}

pub struct Sandbox {
    lua: Lua,
    /// The table `sandbox.lua` returns (`new_env`, `clause_mt`).
    module: Table,
    /// `mdot.vars` for this run: written by config.lua and the host file, read
    /// by specs. One table, shared by every file of the run.
    vars: Table,
}

impl Sandbox {
    pub fn new(facts: &Facts) -> Result<Sandbox, Error> {
        Self::build(facts).map_err(|e| Error::failed(format!("cannot start Lua: {}", lua_message(&e))))
    }

    fn build(facts: &Facts) -> mlua::Result<Sandbox> {
        // Only these libraries are loaded at all; `base` always is. `io`, `os`,
        // `package`, `debug` and `coroutine` never exist in this Lua state.
        let lua = Lua::new_with(
            StdLib::STRING | StdLib::TABLE | StdLib::MATH | StdLib::UTF8,
            LuaOptions::default(),
        )?;

        // `base` still has load/dofile/loadfile/print. User files never see
        // `_G`, but remove them anyway so nothing can hand them out.
        let globals = lua.globals();
        for name in ["load", "dofile", "loadfile", "print", "collectgarbage", "rawset", "rawget",
                     "rawequal", "rawlen", "require"] {
            globals.raw_set(name, Value::Nil)?;
        }

        let os = lua.create_table()?;
        os.set("name", facts.os.name.as_str())?;
        os.set("family", facts.os.family.as_str())?;
        os.set("arch", facts.os.arch.as_str())?;
        os.set("bitness", facts.os.bitness)?;
        // Setting `None` stores nil, so the key is simply absent.
        os.set("distribution", facts.os.distribution.as_deref())?;
        os.set("version", facts.os.version.as_deref())?;
        os.set("codename", facts.os.codename.as_deref())?;
        os.set("edition", facts.os.edition.as_deref())?;
        os.set("hostname", facts.os.hostname.as_str())?;

        let dirs = lua.create_table()?;
        for (name, value) in &facts.dirs {
            dirs.set(*name, value.as_deref())?;
        }
        let dir_names = lua.create_sequence_from(DIR_NAMES)?;

        let write_line = lua.create_function(|lua, text: String| {
            // Level 1 is mdot.print (Lua), level 2 is the user file that called it.
            let (path, line) = match lua.inspect_stack(2) {
                Some(d) => (
                    d.source().short_src.map(|s| s.to_string()).unwrap_or_default(),
                    d.curr_line(),
                ),
                None => (String::new(), 0),
            };
            let mut out = std::io::stdout().lock();
            // Ignore a closed stdout, like print() would.
            let _ = writeln!(out, "{path}:{line}: {text}");
            let _ = out.flush();
            Ok(())
        })?;

        let module: Table = lua
            .load(include_str!("sandbox.lua"))
            .set_name("@<mdot sandbox>")
            .call((os, dirs, dir_names, write_line))?;
        let vars = lua.create_table()?;

        Ok(Sandbox { lua, module, vars })
    }

    /// Runs one file in a fresh environment and returns what it returned.
    /// `rel_path` is the path relative to the repo; errors and `mdot.print`
    /// lines start with it.
    pub fn run(&self, role: Role, rel_path: &str, code: &str) -> Result<Value, Error> {
        let new_env: Function = self.module.get("new_env").map_err(lua_error)?;
        let env: Table = new_env.call((role.as_str(), &self.vars)).map_err(lua_error)?;
        self.lua
            .load(code)
            // A leading `@` makes Lua print the name as is: "specs/a/spec.lua:3:".
            .set_name(format!("@{rel_path}"))
            // Text only: a precompiled (binary) chunk is refused.
            .set_mode(ChunkMode::Text)
            .set_environment(env)
            .eval()
            .map_err(lua_error)
    }

    /// The run's `mdot.vars` table (for the schema check).
    pub fn vars(&self) -> &Table {
        &self.vars
    }

    /// Reads the value a spec or host file returned as a list of clauses.
    /// Lists inside it are flattened depth first, in order (ADR 0018).
    pub fn clauses(&self, rel_path: &str, value: Value) -> Result<Vec<Clause>, Error> {
        let Value::Table(table) = value else {
            return Err(Error::failed(format!(
                "{rel_path}: must return spec {{ ... }}, got {}",
                value.type_name()
            )));
        };
        let clause_mt: Table = self.module.get("clause_mt").map_err(lua_error)?;
        let mut out = Vec::new();
        flatten(rel_path, &clause_mt, &table, "", &mut out)?;
        Ok(out)
    }
}

/// Appends the clauses of `list` to `out`. `prefix` is the position of `list`
/// itself ("" for the top, "2." for the second entry's list), so an error can
/// say "entry 2.1".
fn flatten(
    rel_path: &str,
    clause_mt: &Table,
    list: &Table,
    prefix: &str,
    out: &mut Vec<Clause>,
) -> Result<(), Error> {
    let bad = |pos: String, what: &str| {
        Error::failed(format!("{rel_path}: entry {pos}: {what}"))
    };

    // Every key must be 1..n. `pairs` counts them; raw_len is n.
    let len = list.raw_len();
    let mut count = 0;
    for pair in list.pairs::<Value, Value>() {
        let (key, _) = pair.map_err(lua_error)?;
        match key {
            Value::Integer(i) if i >= 1 && (i as usize) <= len => count += 1,
            other => {
                let shown = match &other {
                    Value::String(s) => s.to_string_lossy().to_string(),
                    v => format!("{v:?}"),
                };
                return Err(bad(format!("{prefix}{shown}"), "not a list position (only clauses go in spec { ... })"));
            }
        }
    }
    if count != len {
        return Err(Error::failed(format!("{rel_path}: spec {{ ... }} has gaps (nil entries)")));
    }

    for i in 1..=len {
        let pos = format!("{prefix}{i}");
        let entry: Value = list.raw_get(i).map_err(lua_error)?;
        let Value::Table(t) = entry else {
            return Err(bad(pos, &format!("not a clause (got {})", entry.type_name())));
        };
        // A clause has clause_mt; a plain list has no metatable at all.
        match t.metatable() {
            Some(mt) if mt == *clause_mt => out.push(read_clause(&t).map_err(lua_error)?),
            Some(_) => return Err(bad(pos, "not a clause")),
            None => flatten(rel_path, clause_mt, &t, &format!("{pos}."), out)?,
        }
    }
    Ok(())
}

/// A clause table as built by sandbox.lua. The file could have changed its
/// fields after the call, so every field is type-checked again here.
fn read_clause(t: &Table) -> mlua::Result<Clause> {
    let kind: String = t.raw_get("kind")?;
    match kind.as_str() {
        "link" => Ok(Clause::Link { src: t.raw_get("src")?, dst: t.raw_get("dst")? }),
        "depends" => Ok(Clause::Depends(t.raw_get("names")?)),
        other => Err(mlua::Error::runtime(format!("unknown clause kind {other}"))),
    }
}

fn lua_error(e: mlua::Error) -> Error {
    Error::failed(lua_message(&e))
}

/// The message of a Lua error without mlua's "runtime error: " prefix and the
/// stack traceback, e.g. "specs/a/spec.lua:4: cannot set string.upper".
fn lua_message(e: &mlua::Error) -> String {
    let text = match e {
        mlua::Error::RuntimeError(m) => m.clone(),
        mlua::Error::SyntaxError { message, .. } => message.clone(),
        mlua::Error::CallbackError { cause, .. } => return lua_message(cause),
        other => other.to_string(),
    };
    match text.split_once("\nstack traceback:") {
        Some((head, _)) => head.to_string(),
        None => text,
    }
}
