use mdot::error::{Code, Error};
use mdot::facts::{Facts, OsFacts, DIR_NAMES};
use mdot::loader::{load, LoadResult, Mode};
use std::fs;
use std::path::{Path, PathBuf};

fn facts(host: &str, home: &Path) -> Facts {
    Facts {
        os: OsFacts {
            name: "linux".into(),
            family: "unix".into(),
            arch: "x86_64".into(),
            bitness: 64,
            distribution: None,
            version: None,
            codename: None,
            edition: None,
            hostname: host.into(),
        },
        dirs: DIR_NAMES
            .iter()
            .map(|n| (*n, (*n == "home").then(|| home.to_string_lossy().into_owned())))
            .collect(),
    }
}

/// A temp repo. `files` is (path relative to the repo, content).
struct Repo {
    dir: tempfile::TempDir,
}

impl Repo {
    fn new(files: &[(&str, &str)]) -> Repo {
        let dir = tempfile::tempdir().unwrap();
        fs::create_dir_all(dir.path().join("repo/specs")).unwrap();
        fs::create_dir_all(dir.path().join("home")).unwrap();
        let repo = Repo { dir };
        for (path, content) in files {
            repo.write(path, content);
        }
        repo
    }
    fn root(&self) -> PathBuf {
        self.dir.path().join("repo")
    }
    fn home(&self) -> PathBuf {
        self.dir.path().join("home")
    }
    fn write(&self, rel: &str, content: &str) {
        let path = self.root().join(rel);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, content).unwrap();
    }
    fn load(&self, host: &str) -> LoadResult {
        load(&self.root(), &facts(host, &self.home()))
    }
}

fn names(r: &LoadResult) -> Vec<&str> {
    r.loaded.specs.iter().map(|s| s.name.as_str()).collect()
}

fn messages(errors: &[Error]) -> Vec<&str> {
    errors.iter().map(|e| e.message.as_str()).collect()
}

#[test]
fn dependency_order_from_adr_0066() {
    let repo = Repo::new(&[
        ("hosts/laptop.lua", r#"return spec { depends("wm", "term") }"#),
        ("specs/wm/spec.lua", r#"return spec { depends("hypr", "fonts") }"#),
        ("specs/term/spec.lua", r#"return spec { depends("fonts", "foot") }"#),
        ("specs/hypr/x", ""),
        ("specs/fonts/x", ""),
        ("specs/foot/x", ""),
        ("specs/rofi/x", ""),
    ]);
    let r = repo.load("laptop");
    assert!(r.errors.is_empty(), "{:?}", r.errors);
    assert_eq!(names(&r), ["hypr", "fonts", "wm", "foot", "term"]);
    assert_eq!(r.loaded.not_reached, ["rofi"]);
}

#[test]
fn implicit_spec_links_its_directory_to_config() {
    let repo = Repo::new(&[("hosts/h.lua", r#"return spec { depends("gdb") }"#), ("specs/gdb/gdbinit", "")]);
    let r = repo.load("h");
    assert!(r.errors.is_empty(), "{:?}", r.errors);
    let gdb = r.loaded.spec("gdb").unwrap();
    assert_eq!(gdb.mode, Mode::Implicit);
    assert_eq!(gdb.links.len(), 1);
    assert_eq!(gdb.links[0].src, repo.root().join("specs/gdb"));
    assert_eq!(gdb.links[0].dst, repo.home().join(".config/gdb"));
}

#[test]
fn explicit_links_are_expanded_and_normalized() {
    let repo = Repo::new(&[
        ("hosts/h.lua", r#"return spec { depends("x11") }"#),
        ("specs/x11/spec.lua", r#"return spec { file.link { "a", "b", into = "~", dot = true }, file.link("./a", "~/x//y/../z") }"#),
        ("specs/x11/a", ""),
        ("specs/x11/b", ""),
    ]);
    let r = repo.load("h");
    assert!(r.errors.is_empty(), "{:?}", r.errors);
    let links = &r.loaded.spec("x11").unwrap().links;
    let pairs: Vec<_> = links.iter().map(|l| (l.src.clone(), l.dst.clone())).collect();
    let s = repo.root().join("specs/x11");
    let h = repo.home();
    assert_eq!(pairs, [(s.join("a"), h.join(".a")), (s.join("b"), h.join(".b")), (s.join("a"), h.join("x/z"))]);
    assert_eq!(links[2].src_shown, "./a");
    assert_eq!(links[2].dst_shown, "~/x//y/../z");
}

#[test]
fn unknown_name_lists_the_known_ones() {
    let repo = Repo::new(&[("hosts/h.lua", r#"return spec { depends("waybr") }"#), ("specs/waybar/x", "")]);
    let r = repo.load("h");
    assert_eq!(messages(&r.errors), [r#"hosts/h.lua: unknown spec "waybr" in depends; specs/ has: waybar"#]);
    assert_eq!(r.errors[0].code, Code::Failed);
}

#[test]
fn a_cycle_is_named() {
    let repo = Repo::new(&[
        ("hosts/h.lua", r#"return spec { depends("a") }"#),
        ("specs/a/spec.lua", r#"return spec { depends("b") }"#),
        ("specs/b/spec.lua", r#"return spec { depends("a") }"#),
    ]);
    let r = repo.load("h");
    assert_eq!(messages(&r.errors), ["depends cycle: a -> b -> a"]);
    assert_eq!(r.errors[0].code, Code::Refused);
}

#[test]
fn src_checks() {
    let repo = Repo::new(&[
        ("hosts/h.lua", r#"return spec { depends("foo") }"#),
        (
            "specs/foo/spec.lua",
            r#"return spec {
                 file.link("conifg", "~/a"),
                 file.link("../bar/x", "~/b"),
                 file.link("escape", "~/c"),
                 file.link("gone", "~/d"),
                 file.link(".", "~/e"),
               }"#,
        ),
        ("specs/bar/x", ""),
    ]);
    let foo = repo.root().join("specs/foo");
    std::os::unix::fs::symlink("../bar/x", foo.join("escape")).unwrap();
    std::os::unix::fs::symlink("nowhere", foo.join("gone")).unwrap();

    let r = repo.load("h");
    let real_x = fs::canonicalize(repo.root().join("specs/bar/x")).unwrap();
    assert_eq!(
        messages(&r.errors),
        [
            r#"foo: src "conifg" does not exist"#.to_string(),
            r#"foo: src "../bar/x" is outside specs/foo/"#.to_string(),
            format!(r#"foo: src "escape" is outside specs/foo/ (resolves to {})"#, real_x.display()),
            r#"foo: src "gone" does not exist (symlink target missing: nowhere)"#.to_string(),
        ]
    );
    let codes: Vec<_> = r.errors.iter().map(|e| e.code).collect();
    assert_eq!(codes, [Code::Failed, Code::Refused, Code::Refused, Code::Failed]);
}

#[test]
fn dollar_in_dst_is_an_error() {
    let repo = Repo::new(&[
        ("hosts/h.lua", r#"return spec { depends("a") }"#),
        ("specs/a/spec.lua", r#"return spec { file.link("f", "$XDG_CONFIG_HOME/a") }"#),
        ("specs/a/f", ""),
    ]);
    let r = repo.load("h");
    assert_eq!(messages(&r.errors), [r#"a: dst "$XDG_CONFIG_HOME/a" contains $; only a leading ~ is expanded"#]);
}

#[test]
fn same_dst_in_two_specs() {
    let repo = Repo::new(&[
        ("hosts/h.lua", r#"return spec { depends("a", "b") }"#),
        ("specs/a/spec.lua", r#"return spec { file.link("f", "~/.f") }"#),
        ("specs/b/spec.lua", r#"return spec { file.link("f", "~/x/../.f") }"#),
        ("specs/a/f", ""),
        ("specs/b/f", ""),
    ]);
    let r = repo.load("h");
    assert_eq!(messages(&r.errors), ["~/x/../.f: dst of both a and b"]);
    assert_eq!(r.errors[0].code, Code::Refused);
}

#[test]
fn host_file_rules() {
    let repo = Repo::new(&[("hosts/h.lua", r#"return spec { file.link("a", "~/a") }"#), ("hosts/other.lua", "")]);
    let r = repo.load("h");
    assert_eq!(messages(&r.errors), ["hosts/h.lua: file.link is not allowed in a host file; put it in a spec"]);

    let r = repo.load("nope");
    assert_eq!(messages(&r.errors), ["hosts/nope.lua does not exist; hosts/ has: h.lua, other.lua"]);
}

#[test]
fn spec_that_declares_nothing() {
    let repo = Repo::new(&[("hosts/h.lua", r#"return spec { depends("a") }"#), ("specs/a/spec.lua", "return spec {}")]);
    let r = repo.load("h");
    assert_eq!(messages(&r.errors), ["specs/a/spec.lua: declares nothing"]);
}

#[test]
fn every_error_is_reported_and_other_specs_still_load() {
    let repo = Repo::new(&[
        ("hosts/h.lua", r#"return spec { depends("bad", "good", "missing") }"#),
        ("specs/bad/spec.lua", "return spec {"),
        ("specs/good/x", ""),
    ]);
    let r = repo.load("h");
    assert_eq!(names(&r), ["good"]);
    assert_eq!(r.errors.len(), 2, "{:?}", r.errors);
}

#[test]
fn config_vars_reach_specs() {
    let repo = Repo::new(&[
        ("config.lua", r#"mdot.vars.dir = "app""#),
        ("hosts/h.lua", r#"mdot.vars.dir = "app2" return spec { depends("a") }"#),
        ("specs/a/spec.lua", r#"return spec { file.link("f", "~/" .. mdot.vars.dir) }"#),
        ("specs/a/f", ""),
    ]);
    let r = repo.load("h");
    assert!(r.errors.is_empty(), "{:?}", r.errors);
    assert_eq!(r.loaded.spec("a").unwrap().links[0].dst, repo.home().join("app2"));
}

/// The real dotfiles fixture loads with no errors.
#[test]
fn test_migration_fixture_loads() {
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).join("test/test-migration");
    let home = tempfile::tempdir().unwrap();
    let r = load(&repo, &facts("nexos", home.path()));
    assert!(r.errors.is_empty(), "{:#?}", r.errors);
    eprintln!("fixture: {} specs reached, {} links, not reached: {:?}", r.loaded.specs.len(), r.loaded.links().count(), r.loaded.not_reached);
    assert!(r.loaded.specs.len() > 20, "only {} specs", r.loaded.specs.len());
    assert!(r.loaded.not_reached.contains(&"legacy".to_string()));
}

#[test]
fn vars_schema_base_errors() {
    let repo = Repo::new(&[
        (
            "config.lua",
            r#"
            mdot.vars.empty = {}
            mdot.vars.mixed = { "A", x = 1 }
            mdot.vars.gaps = { "A", nil, "C" }
            mdot.vars.fn = function() end
            mdot.vars.list = { "a", 2 }
            mdot.vars.recs = { { n = "a", s = 1 }, { n = "b" } }
            "#,
        ),
        ("hosts/h.lua", "return spec {}"),
    ]);
    let r = repo.load("h");
    assert_eq!(
        messages(&r.errors),
        [
            "config.lua: mdot.vars.empty: empty {} is not allowed; give a list at least one element",
            "config.lua: mdot.vars.fn: a function cannot be a var; vars hold only data",
            "config.lua: mdot.vars.gaps: list with gaps: keys must be exactly 1..n",
            "config.lua: mdot.vars.list[2]: expected string, got number",
            "config.lua: mdot.vars.mixed: mixed table: use either string keys (a record) or 1..n (a list)",
            "config.lua: mdot.vars.recs[2].s: removed; a host may not remove a var",
        ]
    );
    assert!(r.errors.iter().all(|e| e.code == Code::Refused));
}

#[test]
fn vars_schema_host_overrides() {
    let repo = Repo::new(&[
        (
            "config.lua",
            r#"
            mdot.vars.font = "Hack"
            mdot.vars.cursor = { name = "c", size = 16 }
            mdot.vars.fonts = { "A", "B" }
            "#,
        ),
        (
            "hosts/ok.lua",
            r#"
            mdot.vars.cursor.size = 24.5
            mdot.vars.fonts = { "A", "B", "C" }
            return spec {}
            "#,
        ),
        (
            "hosts/bad.lua",
            r#"
            mdot.vars.font = 12
            mdot.vars.cursor.colour = "red"
            mdot.vars.cursor.name = nil
            mdot.vars.fonts[3] = 1
            mdot.vars.extra = true
            return spec {}
            "#,
        ),
        (
            "hosts/empty.lua",
            r#"mdot.vars.fonts = {} return spec {}"#,
        ),
    ]);
    assert!(repo.load("ok").errors.is_empty());
    assert!(repo.load("empty").errors.is_empty(), "a host may empty a list");
    let r = repo.load("bad");
    assert_eq!(
        messages(&r.errors),
        [
            "hosts/bad.lua: mdot.vars.cursor.colour: not in config.lua; a host may only override existing vars",
            "hosts/bad.lua: mdot.vars.cursor.name: removed; a host may not remove a var",
            "hosts/bad.lua: mdot.vars.extra: not in config.lua; a host may only override existing vars",
            "hosts/bad.lua: mdot.vars.font: expected string, got number",
            "hosts/bad.lua: mdot.vars.fonts[3]: expected string, got number",
        ]
    );
}
