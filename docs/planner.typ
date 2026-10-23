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

What decides the outcome is not true/false but *which values match each other*. So the planner
splits into a part that is the same for every kind and a part each kind supplies:

#table(
  columns: (1fr, 1fr),
  [Generic], [Per kind],
  [match desired and recorded by ID], [`id(item)`],
  [observe live for each ID, then classify it into a case], [`observe(id)`, `match(a, b)`],
  [return the plan: a list of (ID, action)], [`decide(case)`, its table],
  [], [running an action, which `apply` does later],
)

= The 13 cases

Desired and recorded give four groups (both absent is not a case: nothing names that ID). Live then
has one state per distinct value in play, plus *absent* and *other* (something no spec or record
mentions):

#table(
  columns: (auto, auto, auto, auto),
  [desired], [recorded], [values in play], [live states],
  [X], [—], [1], [absent, desired, other],
  [—], [X], [1], [absent, recorded, other],
  [X], [X (match)], [1], [absent, both, other],
  [X], [Y (differ)], [2], [absent, desired, recorded, other],
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

= Classify: three values in, one case out

```lua
function classify(d, r, l, match)
  local c = { has_d = d ~= nil, has_r = r ~= nil }

  if d and r then
    c.dr = match(d, r) and "same" or "differ"
  end

  if l == nil then
    c.live = "absent"
  else
    local ld = d and match(l, d)
    local lr = r and match(l, r)
    if     ld and lr then c.live = "both"       -- only possible when dr == "same"
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

Matching by ID gives three groups (ADR 0034): desired only (new), both (compare), recorded only (the
spec or clause was removed). Live is not part of the match: the whole filesystem cannot be listed,
so live is observed only for IDs that come out of it.

= The default table

This is the generic table from `design.typ`:

```lua
function generic_decide(c)
  if c.has_d and not c.has_r then
    if c.live == "absent"  then return "create" end
    if c.live == "desired" then return "adopt"  end
    return "conflict"
  end
  if c.has_d and c.has_r then
    if c.live == "both"     then return "noop"   end   -- desired = recorded = live
    if c.live == "recorded" then return "update" end   -- desired changed, live is still ours
    return "conflict_drift"                            -- absent, desired, other
  end
  if not c.has_d and c.has_r then
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
  if c.has_r and c.live == "absent" then
    return c.has_d and "recreate" or "forget"
  end
  if c.has_d and c.has_r and c.dr == "differ" and c.live == "desired" then
    return "adopt"
  end
  return generic_decide(c)
end
```

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
- Whether "same / differ" is enough: downloads tell "only `mode` differs" apart from "`R ≠ D`".
- `match` compares different shapes (an observation, a state record, a clause). For downloads, live
  can only be compared with the record.
