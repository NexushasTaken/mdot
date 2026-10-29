use mdot::facts::{Facts, OsFacts, DIR_NAMES};
use mdot::sandbox::{Clause, Role, Sandbox};

fn facts() -> Facts {
    Facts {
        os: OsFacts {
            name: "linux".into(),
            family: "unix".into(),
            arch: "x86_64".into(),
            bitness: 64,
            distribution: Some("arch".into()),
            version: None,
            codename: None,
            edition: None,
            hostname: "laptop".into(),
        },
        dirs: DIR_NAMES
            .iter()
            .map(|n| (*n, if *n == "config" { Some("/home/u/.config".to_string()) } else { None }))
            .collect(),
    }
}

fn clauses(code: &str) -> Result<Vec<Clause>, String> {
    let sb = Sandbox::new(&facts()).unwrap();
    let v = sb.run(Role::Spec, "specs/a/spec.lua", code).map_err(|e| e.message)?;
    sb.clauses("specs/a/spec.lua", v).map_err(|e| e.message)
}

fn link(src: &str, dst: &str) -> Clause {
    Clause::Link { src: src.into(), dst: dst.into() }
}

/// Runs `code` as a spec and returns the error message (panics if it worked).
fn spec_error(code: &str) -> String {
    let sb = Sandbox::new(&facts()).unwrap();
    match sb.run(Role::Spec, "specs/a/spec.lua", code) {
        Ok(_) => panic!("expected an error from: {code}"),
        Err(e) => e.message,
    }
}

#[test]
fn link_two_strings() {
    let c = clauses(r#"return spec { file.link("config", "~/.config/a") }"#).unwrap();
    assert_eq!(c, vec![link("config", "~/.config/a")]);
}

#[test]
fn link_batch_with_dot() {
    let c = clauses(r#"return spec { file.link { "x", "y", into = "~", dot = true } }"#).unwrap();
    assert_eq!(c, vec![link("x", "~/.x"), link("y", "~/.y")]);
}

#[test]
fn link_batch_without_dot() {
    let c = clauses(r#"return spec { file.link { "u.service", into = "~/.config/systemd/user" } }"#)
        .unwrap();
    assert_eq!(c, vec![link("u.service", "~/.config/systemd/user/u.service")]);
}

#[test]
fn depends_and_nested_lists_keep_order() {
    let c = clauses(
        r#"
        local function two() return { file.link("a", "~/a"), { file.link("b", "~/b") } } end
        return spec { depends("x", "y"), two(), file.link("c", "~/c") }
        "#,
    )
    .unwrap();
    assert_eq!(
        c,
        vec![
            Clause::Depends(vec!["x".into(), "y".into()]),
            link("a", "~/a"),
            link("b", "~/b"),
            link("c", "~/c"),
        ]
    );
}

#[test]
fn bad_link_calls_name_the_line() {
    let e = spec_error("return spec {\n  file.link(\"only-src\"),\n}");
    assert!(e.starts_with("specs/a/spec.lua:2: file.link: expected"), "{e}");
    let e = spec_error(r#"return spec { file.link { "a" } }"#);
    assert!(e.contains("needs `into`"), "{e}");
    let e = spec_error(r#"return spec { file.link { "a", into = "~", typo = 1 } }"#);
    assert!(e.contains("unknown field typo"), "{e}");
    let e = spec_error(r#"return spec { depends("a", 3) }"#);
    assert!(e.contains("depends: argument 2 must be a string"), "{e}");
}

#[test]
fn non_clause_entries_are_errors_with_position() {
    let e = clauses("return spec { 42 }").unwrap_err();
    assert_eq!(e, "specs/a/spec.lua: entry 1: not a clause (got integer)");
    let e = clauses(r#"return spec { file.link("a", "~/a"), { "b" } }"#).unwrap_err();
    assert_eq!(e, "specs/a/spec.lua: entry 2.1: not a clause (got string)");
    // A hand-made table that looks like a clause is just a list with a bad key.
    let e = clauses(r#"return spec { { kind = "link", src = "a", dst = "b" } }"#).unwrap_err();
    assert!(e.contains("not a list position"), "{e}");
    let e = clauses("return 1").unwrap_err();
    assert!(e.contains("must return spec { ... }, got integer"), "{e}");
}

#[test]
fn only_the_allowlist_is_reachable() {
    for name in ["io", "os", "debug", "coroutine", "package", "require", "load", "dofile",
                 "loadfile", "print", "rawset", "rawget", "_G", "collectgarbage"] {
        let code = format!("assert({name} == nil, '{name} is reachable') return spec {{}}");
        clauses(&code).unwrap_or_else(|e| panic!("{e}"));
    }
    clauses(r#"assert(string.dump == nil and ("x").dump == nil) return spec {}"#).unwrap();
    clauses(r#"assert(("x"):upper() == "X") return spec {}"#).unwrap();
}

#[test]
fn library_tables_are_read_only() {
    let e = spec_error("string.upper = nil");
    assert_eq!(e, "specs/a/spec.lua:1: cannot set string.upper");
    let e = spec_error("math.pi = 3");
    assert_eq!(e, "specs/a/spec.lua:1: cannot set math.pi");
    let e = spec_error("file.link = nil");
    assert_eq!(e, "specs/a/spec.lua:1: cannot set file.link");
    // The real string table cannot be reached through a string.
    clauses(r#"assert(getmetatable("") == "locked") return spec {}"#).unwrap();
    let e = spec_error("setmetatable(string, {})");
    assert!(e.contains("protected metatable"), "{e}");
}

#[test]
fn known_quirk_next_and_len_on_libraries() {
    clauses(
        r#"
        assert(next(string) == nil and #math == 0)
        local n = 0
        for _ in pairs(string) do n = n + 1 end
        assert(n > 10)
        return spec {}
        "#,
    )
    .unwrap();
}

#[test]
fn globals_do_not_leak_between_files() {
    let sb = Sandbox::new(&facts()).unwrap();
    sb.run(Role::Spec, "specs/a/spec.lua", "leak = 1 return spec {}").unwrap();
    sb.run(Role::Spec, "specs/b/spec.lua", "assert(leak == nil) return spec {}").unwrap();
}

#[test]
fn mdot_os_and_dirs() {
    clauses(
        r#"
        assert(mdot.os.name == "linux" and mdot.os.bitness == 64)
        assert(mdot.os.hostname == "laptop" and mdot.os.version == nil)
        assert(mdot.dirs.config == "/home/u/.config" and mdot.dirs.state == nil)
        return spec {}
        "#,
    )
    .unwrap();
    assert!(spec_error("local x = mdot.os.hostnme").contains("unknown field mdot.os.hostnme"));
    assert!(spec_error("local x = mdot.dirs.conf").contains("unknown field mdot.dirs.conf"));
    assert!(spec_error("local x = mdot.g").contains("unknown field mdot.g"));
    assert_eq!(spec_error("mdot.os.name = 'x'"), "specs/a/spec.lua:1: cannot set mdot.os.name");
    assert_eq!(spec_error("mdot.vars = {}"), "specs/a/spec.lua:1: cannot set mdot.vars");
}

#[test]
fn vars_flow_from_config_through_host_to_specs() {
    let sb = Sandbox::new(&facts()).unwrap();
    sb.run(Role::Config, "config.lua", r#"mdot.vars.cursor = { name = "c", size = 16 }"#).unwrap();
    sb.run(Role::Host, "hosts/laptop.lua", "mdot.vars.cursor.size = 24 return spec {}").unwrap();
    sb.run(
        Role::Spec,
        "specs/a/spec.lua",
        r#"
        local v = mdot.vars
        assert(v.cursor.size == 24 and v.cursor.name == "c")
        local n = 0
        for k, val in pairs(v.cursor) do n = n + 1 end
        assert(n == 2)
        return spec {}
        "#,
    )
    .unwrap();
    let e = sb.run(Role::Spec, "specs/a/spec.lua", "mdot.vars.cursor.size = 1").unwrap_err();
    assert_eq!(e.message, "specs/a/spec.lua:1: cannot set mdot.vars.cursor.size");
    // A nested table read through pairs() is read-only too.
    let e = sb
        .run(Role::Spec, "specs/a/spec.lua", "for k, t in pairs(mdot.vars) do t.size = 1 end")
        .unwrap_err();
    assert_eq!(e.message, "specs/a/spec.lua:1: cannot set mdot.vars.cursor.size");
}

#[test]
fn syntax_errors_name_the_file() {
    let e = spec_error("return spec {");
    assert!(e.starts_with("specs/a/spec.lua:1:"), "{e}");
}
