//! design.typ "Phase 1 acceptance test", run against the real binary with a
//! fixture repo, a temp $HOME and a temp state directory.

use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

struct Env {
    _tmp: tempfile::TempDir,
    root: PathBuf,
}

impl Env {
    fn new() -> Env {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().to_path_buf();
        let (host, _) = mdot::host::real_hostname().unwrap();
        let files = [
            (format!("hosts/{host}.lua"), r#"return spec { depends("bash", "gdb") }"#),
            ("specs/bash/spec.lua".into(), r#"return spec { file.link("bashrc", "~/.bashrc"), file.link("env", "~/.config/bash/env") }"#),
            ("specs/bash/bashrc".into(), ""),
            ("specs/bash/env".into(), ""),
            ("specs/gdb/gdbinit".into(), ""),
        ];
        for (rel, content) in files {
            let p = root.join("repo").join(rel);
            fs::create_dir_all(p.parent().unwrap()).unwrap();
            fs::write(p, content).unwrap();
        }
        fs::create_dir_all(root.join("home")).unwrap();
        Env { _tmp: tmp, root }
    }

    fn home(&self) -> PathBuf {
        self.root.join("home")
    }
    fn repo(&self) -> PathBuf {
        self.root.join("repo")
    }

    fn mdot(&self, args: &[&str]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_mdot"))
            .args(["--repo", self.repo().to_str().unwrap()])
            .args(args)
            .env("HOME", self.home())
            .env("XDG_STATE_HOME", self.root.join("state"))
            .env_remove("XDG_CONFIG_HOME")
            .output()
            .unwrap()
    }
}

fn stdout(o: &Output) -> String {
    String::from_utf8_lossy(&o.stdout).into_owned()
}
fn stderr(o: &Output) -> String {
    String::from_utf8_lossy(&o.stderr).into_owned()
}

fn points_to(link: &Path) -> PathBuf {
    fs::read_link(link).unwrap()
}

#[test]
fn phase_1_acceptance() {
    let env = Env::new();

    // 1. plan lists the links to create (and creates nothing, not even state).
    let o = env.mdot(&["plan"]);
    assert_eq!(o.status.code(), Some(0), "{}", stderr(&o));
    assert_eq!(
        stdout(&o),
        "bash\n  + link  ~/.bashrc -> bashrc\n  + link  ~/.config/bash/env -> env\n\
         gdb\n  + link  ~/.config/gdb -> .\n\nPlan: 3 to create.\n"
    );
    assert!(!env.root.join("state").exists());

    // 2. apply creates them.
    let o = env.mdot(&["apply", "--yes"]);
    assert_eq!(o.status.code(), Some(0), "{}", stderr(&o));
    assert!(stdout(&o).ends_with("Applied: 3 created.\n"), "{}", stdout(&o));
    assert_eq!(points_to(&env.home().join(".bashrc")), env.repo().join("specs/bash/bashrc"));
    assert_eq!(points_to(&env.home().join(".config/gdb")), env.repo().join("specs/gdb"));
    let state = fs::read_to_string(env.root.join("state/mdot-data/state.json")).unwrap();
    assert!(state.contains(&env.home().join(".config/bash").display().to_string()), "{state}");

    // 3. plan again shows nothing to do.
    let o = env.mdot(&["plan"]);
    assert_eq!(o.status.code(), Some(0), "{}", stderr(&o));
    assert_eq!(stdout(&o), "No changes.\n");

    // 4. After a spec is removed, plan shows the removals, and apply cleans up
    //    the directory mdot created for it.
    let (host, _) = mdot::host::real_hostname().unwrap();
    fs::write(env.repo().join(format!("hosts/{host}.lua")), r#"return spec { depends("gdb") }"#).unwrap();
    let o = env.mdot(&["plan"]);
    assert_eq!(o.status.code(), Some(0), "{}", stderr(&o));
    assert_eq!(
        stdout(&o),
        "bash\n  - link  ~/.bashrc  (spec removed)\n  - link  ~/.config/bash/env  (spec removed)\n\nPlan: 2 to delete.\n"
    );
    let o = env.mdot(&["apply", "--yes"]);
    assert_eq!(o.status.code(), Some(0), "{}", stderr(&o));
    assert!(!env.home().join(".bashrc").exists());
    assert!(!env.home().join(".config/bash").exists(), "created dir left behind");
    // ~/.config was created by mdot too, but gdb still lives under it.
    assert!(env.home().join(".config").exists());

    // 5. A link retargeted by hand is a conflict (drift), and plan exits 1.
    let gdb = env.home().join(".config/gdb");
    fs::remove_file(&gdb).unwrap();
    symlink("/elsewhere", &gdb).unwrap();
    let o = env.mdot(&["plan"]);
    assert_eq!(o.status.code(), Some(1));
    assert_eq!(stdout(&o), "gdb\n  ! link  ~/.config/gdb -> .\n\nPlan: 1 conflict.\n");
    assert_eq!(
        stderr(&o),
        "conflict: ~/.config/gdb: symlink to /elsewhere, changed since mdot made it\n"
    );

    // apply refuses before asking, even with --yes (ADR 0069).
    let o = env.mdot(&["apply", "--yes"]);
    assert_eq!(o.status.code(), Some(1));
    assert_eq!(stderr(&o), "conflict: apply refused; run 'mdot plan' to review\n");
}

#[test]
fn apply_without_a_terminal_needs_yes() {
    let env = Env::new();
    let o = env.mdot(&["apply"]);
    assert_eq!(o.status.code(), Some(1));
    assert!(stderr(&o).contains("stdin is not a terminal; use --yes"), "{}", stderr(&o));
}

#[test]
fn load_errors_exit_2() {
    let env = Env::new();
    fs::write(env.repo().join("specs/bash/spec.lua"), "return spec {").unwrap();
    let o = env.mdot(&["plan"]);
    assert_eq!(o.status.code(), Some(2));
    assert!(stderr(&o).starts_with("error: specs/bash/spec.lua:1:"), "{}", stderr(&o));
}

#[test]
fn mdot_print_writes_path_and_line() {
    let env = Env::new();
    fs::write(
        env.repo().join("specs/bash/spec.lua"),
        "mdot.print('hi', 1)\nreturn spec { file.link('bashrc', '~/.bashrc') }",
    )
    .unwrap();
    let o = env.mdot(&["plan"]);
    assert!(stdout(&o).starts_with("specs/bash/spec.lua:1: hi\t1\n"), "{}", stdout(&o));
}

#[test]
fn verbose_levels() {
    let env = Env::new();
    env.mdot(&["apply", "--yes"]);
    assert_eq!(stdout(&env.mdot(&["plan"])), "No changes.\n");
    let o = env.mdot(&["plan", "-v"]);
    assert!(stdout(&o).contains("gdb\n  = link  ~/.config/gdb -> .\n"), "{}", stdout(&o));
    let o = env.mdot(&["plan", "--verbose=2"]);
    let expected = format!(
        "  = link  ~/.config/gdb -> .\n      desired:  {0}\n      recorded: {0}\n      live:     symlink to {0}\n",
        env.repo().join("specs/gdb").display()
    );
    assert!(stdout(&o).contains(&expected), "{}", stdout(&o));
}

#[test]
fn color_flag() {
    let env = Env::new();
    fs::write(env.repo().join("specs/bash/spec.lua"), "return spec {").unwrap();
    let o = env.mdot(&["plan", "--color=always"]);
    assert!(stderr(&o).starts_with("\x1b[31merror:\x1b[0m "), "{:?}", stderr(&o));
    let o = env.mdot(&["plan"]);
    assert!(stderr(&o).starts_with("error: "), "not a terminal: no color");
}

#[test]
fn preview_ignores_state_and_live() {
    let env = Env::new();
    env.mdot(&["apply", "--yes"]);
    fs::write(env.repo().join("hosts/phone.lua"), r#"return spec { depends("gdb") }"#).unwrap();
    let o = env.mdot(&["preview", "phone"]);
    assert_eq!(o.status.code(), Some(0), "{}", stderr(&o));
    assert_eq!(stdout(&o), "gdb\n  + link  ~/.config/gdb -> .\n\nPlan: 1 to create.\n");

    let o = env.mdot(&["preview", "Phone"]);
    assert_eq!(o.status.code(), Some(2));
    let o = env.mdot(&["preview", "nope"]);
    assert_eq!(o.status.code(), Some(2));
    assert!(stderr(&o).contains("hosts/nope.lua does not exist"), "{}", stderr(&o));
}

#[test]
fn specs_command() {
    let env = Env::new();
    fs::write(env.repo().join("hosts/laptop.lua"), r#"return spec { depends("desktop", "bash") }"#).unwrap();
    let files = [
        ("specs/desktop/spec.lua", r#"return spec { depends("hypr", "waybar") }"#),
        ("specs/hypr/x", ""),
        ("specs/waybar/x", ""),
        ("specs/rofi/x", ""),
    ];
    for (rel, content) in files {
        let p = env.repo().join(rel);
        fs::create_dir_all(p.parent().unwrap()).unwrap();
        fs::write(p, content).unwrap();
    }
    let o = env.mdot(&["specs", "--host", "laptop"]);
    assert_eq!(o.status.code(), Some(0), "{}", stderr(&o));
    assert_eq!(
        stdout(&o),
        "hypr\n  needed by:  desktop\nwaybar\n  needed by:  desktop\n\
         desktop\n  depends on: hypr, waybar\n  needed by:  laptop (host)\n\
         bash\n  needed by:  laptop (host)\nnot reached: gdb, rofi\n"
    );

    let o = env.mdot(&["specs", "desktop", "--host", "laptop"]);
    assert_eq!(stdout(&o), "desktop\n  depends on: hypr, waybar\n  needed by:  laptop (host)\n");
    let o = env.mdot(&["specs", "rofi", "--host", "laptop"]);
    assert_eq!(stdout(&o), "not reached: rofi\n");
    let o = env.mdot(&["specs", "nope", "--host", "laptop"]);
    assert_eq!(o.status.code(), Some(2));

    // A missing depends name: the error, then what loaded.
    fs::write(env.repo().join("specs/desktop/spec.lua"), r#"return spec { depends("hypr", "waybr") }"#).unwrap();
    let o = env.mdot(&["specs", "desktop", "--host", "laptop"]);
    assert_eq!(o.status.code(), Some(2));
    assert!(stderr(&o).contains(r#"unknown spec "waybr""#), "{}", stderr(&o));
    assert_eq!(stdout(&o), "desktop\n  depends on: hypr, waybr (missing)\n  needed by:  laptop (host)\n");
}
