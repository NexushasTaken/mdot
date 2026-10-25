// Port of test/test_spec_lua.cpp.
use mdot::spec_lua::parse_spec;

#[test]
fn valid_empty_spec() {
    let r = parse_spec(
        "test",
        r#"
        return spec {}
        "#,
    )
    .unwrap();
    assert!(r.link_clauses.is_empty());
}

#[test]
fn valid_spec_with_one_clause() {
    let r = parse_spec(
        "test",
        r#"
        return spec {
          file.link("src", "dst"),
        }
        "#,
    )
    .unwrap();
    assert_eq!(r.link_clauses.len(), 1);
    assert_eq!(r.link_clauses[0].src, "src");
    assert_eq!(r.link_clauses[0].dst, "dst");
}

#[test]
fn valid_spec_with_one_bad_clause_call() {
    let r = parse_spec(
        "test",
        r#"
        return spec {
          file.link("src"),
        }
        "#,
    );
    assert_eq!(r.unwrap_err(), "entry 1: `dst` is required");

    let r = parse_spec(
        "test",
        r#"
        return spec {
          file.link(),
        }
        "#,
    );
    assert_eq!(r.unwrap_err(), "entry 1: `src` is required");
}

#[test]
fn non_table_return() {
    let r = parse_spec(
        "test",
        r#"
        return "non-table"
        "#,
    );
    assert_eq!(r.unwrap_err(), "test: spec must return a table, got string");
}

#[test]
fn not_clause() {
    let r = parse_spec(
        "test",
        r#"
        return spec {
          "not-clause"
        }
        "#,
    );
    assert_eq!(r.unwrap_err(), "entry 1: is not a valid clause call");
}
