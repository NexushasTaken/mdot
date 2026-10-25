#import "../template.typ": adr

#adr(number: 39, title: [`mdot.vars` is typed by a schema built from base; the "User's fault" boundary is widened], status: [Accepted], date: [2026-10-25])[
= Context
ADR 0038 makes `config.lua` define the base `mdot.vars` and lets a host file only override keys
the base has. It left open whether an override may change a value's type. Its key check ("after
the host file runs, `mdot.vars` has exactly the base's keys") also forbids a host from changing a
list's length, because a Lua list is a table with keys `1..n`. Lua has one table type, so records
(`{ name = …, size = … }`) and lists (`{ "A", "B" }`) look the same to mdot.

Marker expressions are Lua (ADR 0037), and the clean filter evaluates them with the base `vars`. A
marker that indexes past the end of a base list gets `nil` there. ADR 0037 left open which replace
functions exist.

`design.typ`'s "User's fault" boundary only covered paths that conflict from the target software's
point of view.

= Options
- *Type changes in a host override:* allow them, or forbid them.
- *An empty `{}` in base:* an empty list whose element type the host decides (Claude's
  recommendation), or an error.
- *Integer vs float:* one type `number`, or two types (`math.type`).

= Decision
From the author:

- *A host override cannot change a value's type.* The author's reason: a spec that computes with a
  var (arithmetic, comparisons) expects the same type on every host, and specs should not need
  `type()` checks to protect themselves.
- *mdot builds a schema from the base `mdot.vars` at runtime and validates the host's overrides
  against it.* Every error is shown to the user.
- *Records* have string keys. Each value keeps its base type: a string cannot become a number.
- *Lists* hold elements of one type. A host may change a list's length, but not its element type.
  This replaces ADR 0038's "exactly the base's keys" for lists.
- *An empty `{}` in base is an error.* The author rejected Claude's recommendation to read it as an
  empty list. A consequence: a list cannot be empty by default.
- *Integers and floats are one type, `number`.* The author's reason: that is how Lua treats them
  (`type(16.0)` is `"number"`, `16 == 16.0`). A host may override `16` with `24.5`.
- *A marker that indexes past the end of a list is the user's to handle,* with a fallback in the
  expression (`vars.fonts[3] or "C"`). Without one, the strict parameter types of the marker
  functions turn `nil` into an error that mdot shows.
- *Marker functions have strict parameter types.* An argument of a type the function does not
  accept, including `nil`, is an error.
- *The "User's fault" boundary is widened* beyond paths. The author's reasoning: marker expressions
  are Lua, so handling a missing value is the user's job; "User's fault" does not mean mdot hides
  the problem, and mdot shows errors as much as it can.

Accepted additions proposed by Claude:

- *A mixed table* (`{ "A", x = 1 }`) in base is an error: it is neither a record nor a list.
- *A list with gaps* (`{ "A", nil, "C" }`) is an error: a list's keys must be exactly `1..n`.
- *A list of records:* every element, in base or added by a host, must match the shape (keys and
  value types) of the base list's first element.
- *Errors are all reported in one run,* each naming the key path (`cursor.size`) and the host file.
- *The principle's wording,* in `design.typ`: mdot does not try to predict mistakes that depend on
  what the user writes (paths that conflict for the target software, a marker expression with no
  value on some host); it reports every error it does find, naming the problem.
- *`replace_number` writes `tostring(v)`,* unchanged. A host value `24.0` is written as `24.0`.
- *Exactly two marker functions in v1,* the two the author's Yolk repo uses (seven markers in five
  files: git name and email, alacritty font and the hyprland cursor name are quoted; three cursor
  sizes are numbers):
  - `replace_quoted(v)`: `v` is a string or a number. Replaces the text inside the quotes on the
    line.
  - `replace_number(v)`: `v` is a number. Replaces the number on the line.

  More functions are added when a real file needs one. The author accepted both function
  recommendations because every marker function will be documented, including what it does with
  `v`.

= Consequences
- Closes ADR 0038's open item on type changes, and amends its key check for lists. ADR 0038 itself
  is unchanged.
- Closes the replace-functions part of ADR 0037's open item. The marker clause's name stays open.
- The "no type change" rule is part of the schema, so one check covers keys, types and list
  elements.
- A list that some hosts leave empty cannot be expressed: base needs at least one element.
- Changes `design.typ`'s "User's fault" principle.
]
