//! The clause constructors that user files call: `spec`, `file.link` and
//! `depends` (design.typ "Lua API", ADR 0018, 0019, 0022).
//!
//! They are Rust functions; `sandbox.lua` only puts them into each file's
//! environment. Each one checks its arguments and returns its `Clause` as Lua
//! userdata, so `sandbox.rs` reads the result back as Rust data with nothing
//! left to check. A file cannot forge a clause or change one after the call:
//! userdata has no fields, and mlua locks its metatable (`__metatable`).

use mlua::{Function, Lua, MultiValue, Table, UserData, Value};
use std::fmt::Display;

/// What a clause call produced, as plain Rust data.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Clause {
    /// `file.link(src, dst)`, or one name of the batch form. Both strings are as
    /// written; the loader expands and checks them.
    Link { src: String, dst: String },
    /// `depends(names...)`.
    Depends(Vec<String>),
}

impl UserData for Clause {}

/// The constructors, ready to hand to `sandbox.lua`.
pub struct Constructors {
    pub spec: Function,
    pub file_link: Function,
    pub depends: Function,
}

pub fn create(lua: &Lua) -> mlua::Result<Constructors> {
    Ok(Constructors {
        spec: lua.create_function(|lua, value: Value| spec(lua, value))?,
        file_link: lua.create_function(|lua, args: MultiValue| file_link(lua, args))?,
        depends: lua.create_function(|lua, args: MultiValue| depends(lua, args))?,
    })
}

/// An error that starts with the caller's position, like Lua's `error(msg, 2)`:
/// "specs/a/spec.lua:3: file.link: ...".
fn caller_error(lua: &Lua, msg: impl Display) -> mlua::Error {
    // Level 0 is this Rust function, level 1 the Lua code that called it.
    let pos = lua
        .inspect_stack(1)
        .and_then(|d| {
            let src = d.source().short_src?.to_string();
            Some(format!("{src}:{}: ", d.curr_line()))
        })
        .unwrap_or_default();
    mlua::Error::runtime(format!("{pos}{msg}"))
}

fn text(s: &mlua::String) -> mlua::Result<String> {
    Ok(s.to_str()?.to_string())
}

fn userdata(lua: &Lua, clause: Clause) -> mlua::Result<Value> {
    lua.create_userdata(clause).map(Value::UserData)
}

/// `spec { ... }` only checks that it got a table. Flattening and checking each
/// entry happens in sandbox.rs, after the file has returned.
fn spec(lua: &Lua, value: Value) -> mlua::Result<Value> {
    match value {
        Value::Table(_) => Ok(value),
        _ => Err(caller_error(lua, "spec: expected a table: spec { ... }")),
    }
}

/// `file.link(src, dst)` or `file.link { names..., into = dir, dot? }` (ADR 0022).
fn file_link(lua: &Lua, args: MultiValue) -> mlua::Result<Value> {
    let args: Vec<Value> = args.into_iter().collect();
    match args.as_slice() {
        [Value::String(src), Value::String(dst)] => {
            userdata(lua, Clause::Link { src: text(src)?, dst: text(dst)? })
        }
        [Value::Table(t)] if t.metatable().is_none() => link_batch(lua, t),
        _ => Err(caller_error(
            lua,
            "file.link: expected file.link(src, dst) or file.link { names..., into = dir }",
        )),
    }
}

/// The batch form. It returns a plain list of link clauses; sandbox.rs
/// flattens lists.
fn link_batch(lua: &Lua, t: &Table) -> mlua::Result<Value> {
    let count = t.raw_len();
    let mut into = None;
    let mut dot = false;
    for pair in t.pairs::<Value, Value>() {
        let (key, value) = pair?;
        match &key {
            Value::String(k) if *k == "into" => match value {
                Value::String(s) => into = Some(text(&s)?),
                _ => return Err(caller_error(lua, "file.link: `into` must be a string")),
            },
            Value::String(k) if *k == "dot" => match value {
                Value::Boolean(b) => dot = b,
                _ => return Err(caller_error(lua, "file.link: `dot` must be a boolean")),
            },
            Value::Integer(i) if *i >= 1 && (*i as usize) <= count => {
                if !value.is_string() {
                    return Err(caller_error(lua, format!("file.link: name {i} must be a string")));
                }
            }
            _ => {
                let tostring: Function = lua.globals().get("tostring")?;
                let shown: String = tostring.call(key)?;
                return Err(caller_error(lua, format!("file.link: unknown field {shown}")));
            }
        }
    }
    let Some(into) = into else {
        return Err(caller_error(lua, "file.link: the batch form needs `into`"));
    };
    if count == 0 {
        return Err(caller_error(lua, "file.link: the batch form needs at least one name"));
    }

    let prefix = format!("{into}{}", if dot { "/." } else { "/" });
    let out = lua.create_table()?;
    for i in 1..=count {
        let name: String = t.raw_get(i)?;
        // dst uses only the last path component; src stays the whole name (ADR 0022).
        let last = name.rsplit('/').next().unwrap_or("");
        // TODO(design): a name with no file name is a guess (adr/todo.typ).
        if matches!(last, "" | "." | "..") {
            return Err(caller_error(lua, format!("file.link: name {i} ({name:?}) has no file name")));
        }
        let dst = format!("{prefix}{last}");
        out.raw_push(userdata(lua, Clause::Link { src: name, dst })?)?;
    }
    Ok(Value::Table(out))
}

/// `depends(names...)` (ADR 0019).
fn depends(lua: &Lua, args: MultiValue) -> mlua::Result<Value> {
    let mut names = Vec::new();
    for (i, value) in args.into_iter().enumerate() {
        match value {
            Value::String(s) => names.push(text(&s)?),
            _ => {
                return Err(caller_error(lua, format!("depends: argument {} must be a string", i + 1)))
            }
        }
    }
    userdata(lua, Clause::Depends(names))
}
