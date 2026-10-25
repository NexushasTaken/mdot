use crate::error::ClauseError;
use crate::spec::{LinkClause, Spec};
use mlua::{Lua, LuaOptions, StdLib, Table, Value};

// C++ `state.open_libraries(base, string, table, math, package)`. mlua always opens
// `base`; the rest are bit flags.
fn state_setup() -> Result<Lua, String> {
    let lua = Lua::new_with(
        StdLib::STRING | StdLib::TABLE | StdLib::MATH | StdLib::PACKAGE,
        LuaOptions::default(),
    )
    .map_err(|e| e.to_string())?;

    lua.load(
        r#"
        file = {}
        function spec(clauses)
          return clauses
        end
        function file.link(src, dst)
          return { src = src, dst = dst }
        end
        "#,
    )
    .set_name("prelude")
    .exec()
    .map_err(|e| e.to_string())?;

    Ok(lua)
}

// C++ `get_or<std::optional<std::string>>("src", std::nullopt)`. In mlua, reading a
// missing key as `Option<String>` gives `None`. A value of the wrong type is an Err.
fn link_clause_from_table(id: usize, raw_clause: &Table) -> Result<LinkClause, ClauseError> {
    let src: Option<String> = raw_clause
        .get("src")
        .map_err(|e| ClauseError::new(id, format!("`src`: {e}")))?;
    let dst: Option<String> = raw_clause
        .get("dst")
        .map_err(|e| ClauseError::new(id, format!("`dst`: {e}")))?;

    // `let ... else` = "unwrap this or bail out".
    let Some(src) = src else {
        return Err(ClauseError::new(id, "`src` is required"));
    };
    let Some(dst) = dst else {
        return Err(ClauseError::new(id, "`dst` is required"));
    };

    Ok(LinkClause { src, dst })
}

pub fn parse_spec(name: &str, spec_code: &str) -> Result<Spec, String> {
    let mut spec = Spec::default();

    let lua = state_setup()?;

    let spec_result: Value = lua
        .load(spec_code)
        .set_name(name)
        .eval()
        .map_err(|e| e.to_string())?;

    let Value::Table(raw_spec) = spec_result else {
        return Err(format!(
            "{name}: spec must return a table, got {}",
            spec_result.type_name()
        ));
    };

    for i in 1..=raw_spec.raw_len() {
        let spec_element: Value = raw_spec.raw_get(i).map_err(|e| e.to_string())?;
        let Value::Table(clause) = spec_element else {
            return Err(ClauseError::new(i, "is not a valid clause call").to_string());
        };

        let clause = link_clause_from_table(i, &clause).map_err(|e| e.to_string())?;
        spec.link_clauses.push(clause);
    }

    Ok(spec)
}
