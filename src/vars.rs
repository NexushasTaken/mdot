//! The `mdot.vars` schema (ADR 0038, 0039).
//!
//! After config.lua runs, `schema` reads the base `mdot.vars` into a type tree
//! and checks the base itself. After the host file runs, `check_host` checks
//! the (possibly overridden) table against that tree. Every error is
//! collected, so one run reports them all.

use mlua::{Table, Value};
use std::collections::BTreeMap;

/// The type of one var, built from base.
#[derive(Debug, Clone, PartialEq)]
pub enum Schema {
    Str,
    /// Integers and floats are one type (ADR 0039).
    Num,
    Bool,
    /// String keys; each keeps its base type.
    Record(BTreeMap<String, Schema>),
    /// Keys exactly 1..n; every element has the type of base's first one.
    List(Box<Schema>),
}

impl Schema {
    fn name(&self) -> &'static str {
        match self {
            Schema::Str => "string",
            Schema::Num => "number",
            Schema::Bool => "boolean",
            Schema::Record(_) => "record",
            Schema::List(_) => "list",
        }
    }
}

/// What a Lua table is, judged by its keys.
enum Shape {
    Empty,
    Record(Vec<(String, Value)>),
    /// Values in order 1..n.
    List(Vec<Value>),
    Gaps,
    Mixed,
}

fn shape(t: &Table) -> mlua::Result<Shape> {
    let mut strings = Vec::new();
    let mut ints = Vec::new();
    let mut other = false;
    for pair in t.pairs::<Value, Value>() {
        let (k, v) = pair?;
        match k {
            Value::String(s) => strings.push((s.to_string_lossy().to_string(), v)),
            Value::Integer(i) => ints.push((i, v)),
            _ => other = true,
        }
    }
    Ok(match (strings.is_empty(), ints.is_empty(), other) {
        (true, true, false) => Shape::Empty,
        (false, true, false) => {
            // Sorted, so errors come out in a stable order.
            strings.sort_by(|a, b| a.0.cmp(&b.0));
            Shape::Record(strings)
        }
        (true, false, false) => {
            ints.sort_by_key(|(i, _)| *i);
            let is_1_to_n = ints.iter().enumerate().all(|(n, (i, _))| *i == n as i64 + 1);
            if is_1_to_n {
                Shape::List(ints.into_iter().map(|(_, v)| v).collect())
            } else {
                Shape::Gaps
            }
        }
        _ => Shape::Mixed,
    })
}

fn lua_type(v: &Value) -> &'static str {
    match v {
        Value::Integer(_) | Value::Number(_) => "number",
        Value::String(_) => "string",
        Value::Boolean(_) => "boolean",
        Value::Table(_) => "table",
        Value::Nil => "nil",
        Value::Function(_) => "function",
        _ => "non-data value",
    }
}

/// Builds the schema from the base vars (`config.lua`'s `mdot.vars`).
/// `file` names the file in errors.
pub fn schema(vars: &Table, file: &str) -> Result<Schema, Vec<String>> {
    let mut errors = Vec::new();
    let s = build(&Value::Table(vars.clone()), "mdot.vars", file, &mut errors);
    match s {
        Some(s) if errors.is_empty() => Ok(s),
        _ => Err(errors),
    }
}

fn build(v: &Value, path: &str, file: &str, errors: &mut Vec<String>) -> Option<Schema> {
    let mut err = |msg: String| errors.push(format!("{file}: {path}: {msg}"));
    match v {
        Value::String(_) => Some(Schema::Str),
        Value::Integer(_) | Value::Number(_) => Some(Schema::Num),
        Value::Boolean(_) => Some(Schema::Bool),
        Value::Table(t) => match shape(t) {
            Err(e) => {
                err(e.to_string());
                None
            }
            // The root may be empty: no config.lua vars at all is fine.
            Ok(Shape::Empty) if path == "mdot.vars" => Some(Schema::Record(BTreeMap::new())),
            Ok(Shape::Empty) => {
                err("empty {} is not allowed; give a list at least one element".into());
                None
            }
            Ok(Shape::Mixed) => {
                err("mixed table: use either string keys (a record) or 1..n (a list)".into());
                None
            }
            Ok(Shape::Gaps) => {
                err("list with gaps: keys must be exactly 1..n".into());
                None
            }
            Ok(Shape::Record(fields)) => {
                let mut map = BTreeMap::new();
                for (k, v) in fields {
                    if let Some(s) = build(&v, &format!("{path}.{k}"), file, errors) {
                        map.insert(k, s);
                    }
                }
                Some(Schema::Record(map))
            }
            Ok(Shape::List(items)) => {
                let first = build(&items[0], &format!("{path}[1]"), file, errors)?;
                // Every element matches the first one's type and shape.
                for (i, item) in items.iter().enumerate().skip(1) {
                    check(item, &first, &format!("{path}[{}]", i + 1), file, errors);
                }
                Some(Schema::List(Box::new(first)))
            }
        },
        other => {
            err(format!("a {} cannot be a var; vars hold only data", lua_type(other)));
            None
        }
    }
}

/// Checks the vars after the host file ran against base's schema.
pub fn check_host(vars: &Table, schema: &Schema, file: &str) -> Vec<String> {
    let mut errors = Vec::new();
    check(&Value::Table(vars.clone()), schema, "mdot.vars", file, &mut errors);
    errors
}

fn check(v: &Value, schema: &Schema, path: &str, file: &str, errors: &mut Vec<String>) {
    let mismatch = |errors: &mut Vec<String>| {
        errors.push(format!(
            "{file}: {path}: expected {}, got {}",
            schema.name(),
            lua_type(v)
        ))
    };
    match (schema, v) {
        (Schema::Str, Value::String(_))
        | (Schema::Num, Value::Integer(_) | Value::Number(_))
        | (Schema::Bool, Value::Boolean(_)) => {}
        (Schema::Record(fields), Value::Table(t)) => match shape(t) {
            Ok(Shape::Record(pairs)) => {
                for (k, val) in &pairs {
                    match fields.get(k) {
                        Some(s) => check(val, s, &format!("{path}.{k}"), file, errors),
                        None => errors.push(format!(
                            "{file}: {path}.{k}: not in config.lua; a host may only override existing vars"
                        )),
                    }
                }
                for k in fields.keys() {
                    if !pairs.iter().any(|(pk, _)| pk == k) {
                        errors.push(format!("{file}: {path}.{k}: removed; a host may not remove a var"));
                    }
                }
            }
            Ok(Shape::Empty) => {
                for k in fields.keys() {
                    errors.push(format!("{file}: {path}.{k}: removed; a host may not remove a var"));
                }
            }
            _ => mismatch(errors),
        },
        (Schema::List(elem), Value::Table(t)) => match shape(t) {
            // A host may change a list's length, even to 0.
            Ok(Shape::Empty) => {}
            Ok(Shape::List(items)) => {
                for (i, item) in items.iter().enumerate() {
                    check(item, elem, &format!("{path}[{}]", i + 1), file, errors);
                }
            }
            Ok(Shape::Gaps) => errors.push(format!("{file}: {path}: list with gaps: keys must be exactly 1..n")),
            _ => mismatch(errors),
        },
        _ => mismatch(errors),
    }
}
