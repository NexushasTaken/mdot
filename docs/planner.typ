#import "template.typ": *

#show: spec.with(
  title: "mdot — The Generic 3-Way Planner",
  meta: [Working notes · 2026-10-24],
)

This page describes the algorithm behind `plan`: how desired, recorded and live become a list of
steps, for any resource kind. The decisions are ADR 0034 (match by ID) and ADR 0035 (classify, then
the kind decides). Each kind's own table is in `design.typ` (`<three-way>`) and its ADR.

The code below is *pseudocode* in Lua syntax. It is generic: it knows nothing about links, paths or
state files. Translating it to C++ is the implementation work.

= The idea

Each of the three sides is either *absent* or *a value*:

- *desired:* what a spec asks for;
- *recorded:* what mdot wrote last time (state);
- *live:* what is on disk now.

*Running example: one link.* A clause `link("nvim", "~/.config/nvim")` is one resource. Its ID is
the `dst`, `~/.config/nvim`. For that ID:

#table(
  columns: (auto, 1fr, 1fr),
  [side],     [a value means],                                                            [absent means],
  [desired],  [a spec asks for a link at this `dst`; the value is its `src`],             [no spec mentions this `dst` (any more)],
  [recorded], [mdot made a link here last time; the value is the `src` it recorded],      [mdot has no record of this `dst`],
  [live],     [something is at this path; for a link the value is its `readlink` string], [nothing at all is at this path],
)

"Absent" is not the same as "empty" or "wrong". An absent side has no value to compare. A side
with a value can still match or not match the others.

What decides the outcome is not true/false but *which values match each other*. So the planner
splits into a part that is the same for every kind and a part each kind supplies:

#table(
  columns: (1fr, 1fr),
  [Generic],                                                [Per kind],
  [match desired and recorded by ID],                       [`id(item)`],
  [observe live for each ID, then classify it into a case], [`observe(id)`, `match(a, b)`],
  [return the plan: a list of (ID, action)],                [`decide(case)`, its table],
  [],                                                       [running an action, which `apply` does later],
)

= The 13 cases

Desired and recorded give four groups (both absent is not a case: nothing names that ID). Live then
has one state per distinct value in play, plus *absent* and *other* (something no spec or record
mentions):

#table(
  columns: (auto, auto, auto, auto),
  [desired], [recorded],   [values in play], [live states],
  [X],       [—],          [1],              [absent, desired, other],
  [—],       [X],          [1],              [absent, recorded, other],
  [X],       [X (match)],  [1],              [absent, both, other],
  [X],       [Y (differ)], [2],              [absent, desired, recorded, other],
)

3 + 3 + 3 + 4 = 13. A kind's table may write fewer rows when several cases share an outcome (ADR
0030 writes the 13 link cases as 11 rows), but every case must be covered. Counting them is the
check.

= What a kind supplies

```lua
kind.id(item)        -> key          -- what makes two items "the same thing"
kind.observe(key)    -> value | nil  -- look at the real world; nil = absent
kind.match(a, b)     -> bool         -- a and b both present; does a "count as" b?
kind.decide(case)    -> action       -- this kind's table (default: generic_decide)
```

For links:

- `id`: the clause's `dst`. Two clauses with the same `dst` are the same resource. Which form of the
  path is used (as written, expanded, normalized) is open (ADR 0034).
- `observe`: looks at `dst` on disk. It returns `nil` if nothing is there, the `readlink` string if
  it is a link, and something that matches nothing if it is a regular file or a directory.
- `match`: the `src` strings are equal (`link-rules.typ`).
- `decide`: ADR 0030's table.

The planner never looks inside a value. It only passes values to `match` and asks "same or not?".
That is what makes it generic.

= Classify: three values in, one case out

`classify` gets the three sides for *one* ID and works out how they relate. It first compares
everything, then names the case. It never stops at the first difference, so the order of the
checks cannot change the result.

Names used in the code:

#table(
  columns: (auto, 1fr),
  [name],      [meaning],
  [`d`],       [the desired value for this ID, or `nil` if no spec asks for it],
  [`r`],       [the recorded value for this ID, or `nil` if mdot has no record of it],
  [`l`],       [the live value, from `observe`, or `nil` if nothing is there],
  [`c`],       [the case: the result of `classify`],
  [`c.desired`], [how desired relates to recorded; always set. `"new"`: desired has this ID and
  recorded does not. `"removed"`: recorded has this ID and desired does not. `"match"`: desired still
  asks for what was recorded. `"differ"`: desired asks for something else now.],
  [`ld`],      [live matches desired: "disk already is what the spec wants"],
  [`lr`],      [live matches recorded: "disk is still what mdot left there"],
  [`c.live`],  [which of them disk agrees with: `absent`, `desired`, `recorded`, `both` or `other`
  (neither: someone else put it there or changed it)],
)

`nil` here is not "false". It means that side has no value for this ID. The `nil`s come from `plan`
below: looking up an ID that is not in the desired or recorded table gives `nil`.

In `d and match(l, d)`, the `and` short-circuits. If `d` is `nil` the result is `nil` and `match` is
never called, because live cannot match a desired value that does not exist.

```lua
function classify(d, r, l, match)
  local c = {}

  if d and r then
    c.desired = match(d, r) and "match" or "differ"
  elseif r == nil then
    c.desired = "new"
  elseif d == nil then
    c.desired = "removed"
  end

  if l == nil then
    c.live = "absent"
  else
    local ld = d and match(l, d)
    local lr = r and match(l, r)
    if     ld and lr then c.live = "both"       -- only possible when desired == "match"
    elseif ld        then c.live = "desired"
    elseif lr        then c.live = "recorded"
    else                  c.live = "other"
    end
  end
  return c
end
```

`classify` never returns an action. It only says which case this is, so it is the same for every
kind.

= Plan: match by ID, then classify each ID

```lua
function plan(kind, desired_items, recorded_items)
  local D = index_by(kind.id, desired_items)   -- error on a duplicate ID: one owner per ID
  local R = index_by(kind.id, recorded_items)

  local steps = {}
  for _, key in ipairs(sorted(union(keys(D), keys(R)))) do  -- sorted: stable output
    local d, r = D[key], R[key]
    local l    = kind.observe(key)                         -- only known IDs are observed
    local c    = classify(d, r, l, kind.match)
    steps[#steps+1] = { key = key, action = kind.decide(c),
                        desired = d, recorded = r, live = l }
  end
  return steps          -- data only: nothing changed. apply() runs the steps later.
end
```

Step by step:

+ `index_by` builds a table from ID to item: `D` for desired (all clauses from all specs), `R` for
  recorded (all entries in state). Two desired items with the same ID are an error, because two
  clauses cannot own the same resource.
+ `union(keys(D), keys(R))` is every ID that appears on either side, each once.
+ For each ID, `D[key]` and `R[key]` are the two items. One of them is `nil` when the ID is on only
  one side. That is where `classify`'s `nil`s come from.
+ `observe` looks at the disk for that ID, and `classify` and `decide` turn the three into an action.
+ The step keeps the values too, so `apply` and the plan output know what to do and what to show.

Matching by ID gives three groups (ADR 0034):

#table(
  columns: (auto, auto, 1fr),
  [in `D`], [in `R`], [meaning],
  [yes],    [no],     [new: a spec asks for it, and mdot has not made it yet],
  [yes],    [yes],    [kept: compare what changed],
  [no],     [yes],    [removed: the spec or clause is gone, but mdot made it before],
)

Live is not part of the match. mdot cannot list the whole filesystem, so live is observed only for
IDs that come out of the join. A file that no spec and no record mentions is never looked at.

`index_by`, `union`, `keys` and `sorted` are not shown. They are ordinary table helpers.

= The default table

This is the generic table from `design.typ`. It reads the case, top to bottom, in the three groups
above:

- *New* (`desired == "new"`): create it if nothing is there. Adopt it if someone already made
  exactly what the spec wants. Otherwise something else is in the way: conflict, since mdot never
  overwrites.
- *Kept* (`"match"` or `"differ"`): nothing to do if all three agree. If disk is still what mdot left
  and only the spec changed, update it. Otherwise disk was changed outside mdot: conflict (drift).
- *Removed* (`desired == "removed"`): delete it if disk is still what mdot left. Otherwise conflict,
  because deleting would destroy something mdot did not make.

```lua
function generic_decide(c)
  if c.desired == "new" then
    if c.live == "absent"  then return "create" end
    if c.live == "desired" then return "adopt"  end
    return "conflict"
  end
  if c.desired == "match" or c.desired == "differ" then
    if c.live == "both"     then return "noop"   end   -- desired = recorded = live
    if c.live == "recorded" then return "update" end   -- desired changed, live is still ours
    return "conflict_drift"                            -- absent, desired, other
  end
  if c.desired == "removed" then
    if c.live == "recorded" then return "delete" end
    return "conflict"
  end
end
```

= A kind with its own rows

A kind overrides only the rows that differ and falls back to the default for the rest. For a kind
that follows the link rules (ADR 0030):

```lua
function links_like_decide(c)
  if c.desired ~= "new" and c.live == "absent" then
    return c.desired == "removed" and "forget" or "recreate"
  end
  if c.desired == "differ" and c.live == "desired" then
    return "adopt"
  end
  return generic_decide(c)
end
```

The three rows links change:

- *Recorded, live absent, still desired: `recreate`.* The user deleted the link by hand. Nothing at
  the path can be lost, so mdot makes it again.
- *Recorded, live absent, not desired: `forget`.* The spec dropped it and it is already gone. Only
  the record is removed.
- *The spec changed and disk already matches the new `src`: `adopt`.* Someone already did the
  update by hand. Only the record changes.

Checked by running it: with plain equality as `match`, this gives ADR 0030's result for all 13
cases.

= Testing

`classify` and every `decide` are pure functions. One test per row of a kind's table, with no
filesystem: build `d`, `r`, `l`, call `decide(classify(...))`, compare with the table. Only `observe`
and running an action touch the disk.

= Open

From ADR 0035:

- A separate library, or a module inside mdot with no mdot includes.
- C++ shape: a `virtual` interface or `std::variant`.
- Whether cases a kind's table does not list default to conflict.
- Whether `"match"` / `"differ"` is enough: downloads tell "only `mode` differs" apart from "`R ≠ D`".
- `match` compares different shapes (an observation, a state record, a clause). For downloads, live
  can only be compared with the record.
