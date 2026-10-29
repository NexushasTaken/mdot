#import "template.typ": *

#show: spec.with(
  title: "mdot — Link Handling Rules",
  meta: [Working notes · 2026-10-19],
)

These four rules are what keep `plan_link` and `apply_link` correct. Every symlink bug found so
far broke one of them. Check new link code against this page before debugging it.

The behaviour itself is decided in ADR 0016 (link conflicts). This page is about *how* to
implement it without bugs.

= Normalize once, at the top, then forget the original

Turn every input path into an absolute, lexically normal path in the first lines of the function.
After that, use only the normalized paths, and never the raw arguments.

*Why:* relative paths are interpreted from the current directory. If the raw and normalized
versions are both in scope, sooner or later the wrong one gets passed somewhere (into the plan,
into an error, or into a comparison). The relative-`src` bug was exactly that.

*Check:* after the normalization block, can the raw argument still be reached? If yes, consider
shadowing it or moving normalization to the caller.

= Always store absolute link targets

The string written into a symlink is always the absolute, normalized `src`.

*Why:* a symlink stores only a string. The kernel resolves a relative target from the directory
the *link* is in, not from the cwd at creation time. With absolute targets, the link means the
same thing no matter where it lives or where mdot was run from.

```
$ cd /demo && ln -s photos shortcuts/pics
$ readlink -f shortcuts/pics
/demo/shortcuts/photos        # not /demo/photos
```

*Trade-off:* moving the dotfiles repo breaks every link. That is acceptable for Phase 1 (re-run
`apply`). Relative targets can be revisited later and would need their own ADR.

= The spec is a table; each row gets one test

Inspect `dst` with `symlink_status` (`lstat`: does not follow the link). Ancestors of `dst` are
checked with `status` (follows links, since a symlinked parent directory is fine).

#table(
  columns: (1fr, auto),
  [State on disk], [Plan result],
  [Nothing at `dst`], [Create],
  [`dst` is a symlink whose target, resolved from `dst`'s directory, equals `src`], [Noop],
  [`dst` is a symlink pointing anywhere else, including dangling], [Conflict],
  [`dst` is a regular file, directory, or anything else], [Conflict],
  [An existing ancestor of `dst` is not a directory], [Conflict],
  [`src` does not exist], [Error],
  [Any other filesystem error (`ec` set)], [Error],
)

*Why:* the problem space is finite. When every row has a test, the function is done. Stop there;
anything else is a new feature, not a bug fix.

*Test rules:*
- One test per row, named after the row.
- Assert on the *result* (Create / Noop / Conflict / Error), not only on the filesystem afterwards.
- Assert the variant (`assert_eq!` / `matches!`), not only that a call returned `Ok`. A test that
  just unwraps passes for every `Ok` value, including the wrong one.
- A test that changes cwd must restore it on scope exit, even when an assertion fails.
- Relative-path tests must use a cwd that is *different* from `dst`'s parent, or they cannot
  catch rule 2 bugs.
- Watch a new test fail before fixing the code. A test that was never red proves nothing.

= Plan thinks, apply executes

`plan_link` decides everything and returns the exact paths to use. `apply_link` only carries out
the plan with those paths. It does not re-derive, re-normalize, or reinterpret anything.

*Why:* if apply re-derives anything, plan and apply can disagree, and the plan stops describing what
will happen.

*The one gap:* something can appear at `dst` between plan and apply. `create_symlink` then fails
with "file exists", and that is reported as an error. Good enough for Phase 1; ADR 0016 already
says apply re-checks each link.
