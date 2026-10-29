#import "../template.typ": adr

#adr(number: 80, title: [A link's `src` must resolve inside its spec directory], status: [Accepted], date: [2026-10-29])[
= Context
ADR 0015 makes `src` a path relative to the spec's directory and a missing `src` a load error, but
does not say whether `src` may point outside that directory. ADR 0056 (with `link-rules.typ`)
normalizes every input path once, lexically and to an absolute path, without touching the
filesystem; the link record stores that absolute `src` (ADR 0060) and a link matches when its
`readlink` string equals it (ADR 0030). The sandbox is for purity, not security (ADR 0013).

For a spec in `specs/foo/`:

#table(
  columns: 3,
  [*`src` as written*], [*Normalized*], [*Inside `specs/foo/`?*],
  [`"config"`], [`<repo>/specs/foo/config`], [yes],
  [`"."`], [`<repo>/specs/foo`], [yes (ADR 0015)],
  [`"config/../foo.conf"`], [`<repo>/specs/foo/foo.conf`], [yes],
  [`"../bar/config"`], [`<repo>/specs/bar/config`], [no: another spec's files],
  [`"../../shared/x"`], [`<repo>/shared/x`], [no, but inside the repo],
  [`"/etc/foo.conf"`], [`/etc/foo.conf`], [no, and outside the repo],
)

A lexical check alone misses a symlink committed in the repo: `specs/foo/theme ->
../../shared/theme` stays under `specs/foo/` as a string but reaches `<repo>/shared/theme`.

Lexical normalizing and the OS can also disagree about a `..` right after a symlink. With
`specs/foo/config -> sub/dir`, `"config/../theme"` normalizes to `specs/foo/theme`, while the OS
opens `specs/foo/sub/theme` for the string as written (checked on Linux).

= Options
- *Escaping the spec directory:* allowed, or a hard error.
- *How the check sees the path:* lexically (string rules only), or resolved (following symlinks).
- *Which path the check resolves:* `src` as written, or the normalized `src` that is stored and
  linked.

= Decision
From the author:

- *`src` must stay inside `specs/<spec>/`.* Pointing outside it, to another spec, elsewhere in the
  repo or outside the repo, is a hard error.
- *The check resolves symlinks,* so an in-repo symlink that escapes the spec directory is an error
  too.
- *`src` is normalized lexically (ADR 0056),* and the normalized path is what is stored and linked.
  The last part is not followed. The check resolves this normalized `src`, the path that is
  actually linked, not the string as written. For example, with `specs/foo/config/foo.conf -> ../foo.conf`:

```
file.link("config/foo.conf", "~/.config/foo/foo.conf")

stored and linked:  src = <repo>/specs/foo/config/foo.conf
                    dst = ~/.config/foo/foo.conf  (expanded)
check resolves to:  <repo>/specs/foo/foo.conf     inside specs/foo/, allowed
```

Accepted additions proposed by Claude:

+ *Compared against the resolved spec directory.* Both sides are resolved, so a repo reached
  through a symlink (`~/dotfiles -> /data/dotfiles`) does not make every link fail.
+ *What "inside" means:* the spec directory itself (`"."`) counts as inside. Paths are compared
  component by component, not as a string prefix, so `specs/foo` does not accept `specs/foobar/x`.
+ *Records and matching stay lexical.* The resolved path is used only for this check; ADR 0056 and
  ADR 0030 are unchanged. A symlink inside the spec that resolves inside it is an ordinary `src`.
+ *When:* at load time, right after the missing-`src` check (ADR 0015) and before any planning.
+ *Exit code 1:* the spec loads but breaks a rule (ADR 0053).
+ *Error text:* `error: <spec>: src "<as written>" is outside specs/<spec>/`, followed by
  `(resolves to <path>)` when a symlink caused it.

```
load file.link(src, dst) in spec <spec>:
    norm      = lexical_normalize(<repo>/specs/<spec>/<src>)   # stored and linked (ADR 0056)
    if norm does not exist: load error                         # ADR 0015
    real_spec = resolve(<repo>/specs/<spec>)
    real_src  = resolve(norm)
    if real_src != real_spec and real_src is not under real_spec (by components):
        error: <spec>: src "<src>" is outside specs/<spec>/ [(resolves to <real_src>)]  # exit 1
```

= Consequences
- Each spec only uses its own files. Two specs cannot share one file; each needs its own copy.
- Loading reads the filesystem for this check (it already did for the missing-`src` check).
- Applies to every link the batch form expands to (ADR 0022).
- Open: the exit code for a missing `src` (ADR 0067 covered names only).
]
