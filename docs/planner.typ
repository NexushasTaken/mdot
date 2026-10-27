#import "template.typ": *

#show: spec.with(
  title: "mdot — The Generic 3-Way Planner",
  meta: [Working notes · 2026-10-24],
)

This page describes the algorithm behind `plan`: how desired, recorded and live become a list of
steps, for any resource kind. The decisions are ADR 0034 (match by ID), ADR 0035 (classify, then
the kind decides), ADR 0057 (one comparison per pair), ADR 0058 (every kind decides every case) and ADR 0054 (the kind is part of the ID; apply order). Each kind's own table is in `design.typ` (`<three-way>`) and its ADR.

The code below is *pseudocode* in Lua syntax. It is generic: it knows nothing about links, paths or
state files. Translating it to Rust is the implementation work.

= The idea

Each of the three sides is either *absent* or *a value*:

- *desired:* what a spec asks for;
- *recorded:* what mdot wrote last time (state);
- *live:* what is on disk now.

*Running example: one link.* A clause `link("nvim", "~/.config/nvim")` is one resource. Its ID is
the kind plus the `dst`, `link:~/.config/nvim` (ADR 0054). For that ID:

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
  [observe live for each ID, then classify it into a case], [`observe(id)`, `match_dr`, `match_lr`, `match_ld`],
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
kind.name            -> string       -- "link", "download", ...; the prefix of every ID
kind.id(item)        -> key          -- what makes two items "the same thing"
kind.slot(item)      -> slot         -- the place it occupies: "<world>:<output>" (ADR 0054)
kind.observe(key)    -> value | nil  -- look at the real world; nil = absent
kind.match_dr(d, r)  -> bool         -- desired vs recorded: does the spec still ask for what was recorded?
kind.match_lr(l, r)  -> bool         -- live vs recorded: is disk still what mdot left there?
kind.match_ld(l, d)  -> bool         -- live vs desired; OPTIONAL (nil if the kind can't compare them)
kind.decide(case)    -> action       -- this kind's full table, every case (ADR 0058)
kind.update_detail(step) -> detail   -- optional: which kind of update to show and run (see below)
```

*One comparison per pair* (ADR 0057). Desired, recorded and live can have different shapes, so each
pair has its own comparison. All three get both sides present; `classify` handles the `nil`s.
`match_ld` is optional: a kind that cannot compare live with desired leaves it out, and `plan` then
never adopts that kind (only the two adopt cases need it, see Classify).

For links:

- `id`: `link:` and the clause's `dst` (ADR 0054). Two link clauses with the same `dst` are the same
  resource. The path is expanded, absolute and lexically normal (ADR 0056).
- `slot`: `fs:` and the `dst`. A download at the same `dst` has the same slot.
- `observe`: looks at `dst` on disk. It returns `nil` if nothing is there, the `readlink` string if
  it is a link, and something that matches nothing if it is a regular file or a directory.
- `match_dr`, `match_lr`, `match_ld`: all three are the same test, the `src` strings are equal
  (`link-rules.typ`). All three sides have the same shape.
- `decide`: ADR 0030's table.

For downloads (ADR 0032, ADR 0057):

- `match_dr`: the content keys are equal (`R == D`) and so is `mode`.
- `match_lr`: the live stat equals the recorded one (`size`, `mtime_ns`, `inode`, permission bits).
- `match_ld`: none. Desired has a hash or `url`, live only a stat, and `plan` never hashes.
  Adopting is `mdot verify`'s job (ADR 0024).
- `decide`: the same as links (`links_like_decide` below).
- `update_detail`: `R != D` means download again; otherwise only `mode` changed, so `chmod` and
  update the record.

The planner never looks inside a value. It only passes values to the comparisons and asks "same or
not?". That is what makes it generic.

= Classify: three values in, one case out

`classify` gets the three sides for *one* ID and works out how they relate. It first compares
everything, then names the case. It never stops at the first difference, so the order of the
checks cannot change the result.

*Every side that exists has the same ID.* Any side can be `nil`, but a side with a value never has
a different ID from the others. `classify` does not check this and does not use the ID: `plan`
guarantees it, because it joins desired and recorded by ID and observes live at that same ID.

*At least one of `d` and `r` has a value.* `plan` only loops over IDs from `D` or `R`, so both
absent never reaches `classify` (see "The 13 cases").

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
  [`ld`],      [live matches desired: "disk already is what the spec wants". `nil` when the kind has
  no `match_ld`.],
  [`lr`],      [live matches recorded: "disk is still what mdot left there"],
  [`c.live`],  [which of them disk agrees with: `absent`, `desired`, `recorded`, `both` or `other`
  (neither: someone else put it there or changed it)],
)

`nil` here is not "false". It means that side has no value for this ID. The `nil`s come from `plan`
below: looking up an ID that is not in the desired or recorded table gives `nil`.

In `d and kind.match_ld(l, d)`, the `and` short-circuits. If `d` is `nil` the result is `nil` and
the comparison is never called, because live cannot match a desired value that does not exist.

*`both` does not use `ld`* (ADR 0057). If live matches the record and the record matches desired,
live and desired count as equal. For links this is the same as `ld and lr`, because equality is
transitive. For downloads it is what makes "nothing to do" (stat matches, `R == D`) a `both`, and so
a noop, instead of `recorded`, which would be an update. `ld` is only needed for `desired`, which
only the adopt cases use.

```lua
function classify(d, r, l, kind)
  local c = {}

  if d and r then
    c.desired = kind.match_dr(d, r) and "match" or "differ"
  elseif r == nil then
    c.desired = "new"
  elseif d == nil then
    c.desired = "removed"
  end

  if l == nil then
    c.live = "absent"
  else
    local lr = r and kind.match_lr(l, r)                     -- every kind has it
    local ld = d and kind.match_ld and kind.match_ld(l, d)   -- optional: nil = can't tell
    if     lr and c.desired == "match" then c.live = "both"
    elseif ld                          then c.live = "desired"
    elseif lr                          then c.live = "recorded"
    else                                    c.live = "other"
    end
  end
  return c
end
```

`classify` never returns an action. It only says which case this is, so it is the same for every
kind.

= Plan: match by ID, then classify each ID

The kind is part of the ID (ADR 0054), so `link:~/.foo` and `download:~/.foo` are two IDs. Desired
and recorded are matched per kind, and the steps of all kinds go into one plan.

```lua
function plan(kinds, desired_items, recorded_items)  -- items grouped by kind name
  -- 1. Match desired and recorded by ID, kind by kind.
  local entries = {}
  for _, kind in ipairs(kinds) do
    local D = index_by(kind.id, desired_items[kind.name])  -- error on a duplicate ID: one owner per ID
    local R = index_by(kind.id, recorded_items[kind.name])
    for _, key in ipairs(union(keys(D), keys(R))) do
      entries[#entries+1] = { kind = kind, key = key, d = D[key], r = R[key] }
    end
  end

  -- 2. IDs with a record first, so we know which slots a delete frees.
  local steps, freed = {}, {}
  for _, e in ipairs(entries) do
    if e.r then
      local s = make_step(e, e.kind.observe(e.key))
      if s.action == "delete" then freed[e.kind.slot(e.r)] = true end
      steps[#steps+1] = s
    end
  end

  -- 3. Then the new IDs. A slot freed by a delete in this plan counts as absent (ADR 0054).
  --    (Rule 2: needed once a second kind writes files; with links only, freed never matches.)
  for _, e in ipairs(entries) do
    if not e.r then
      local l
      if freed[e.kind.slot(e.d)] then l = nil else l = e.kind.observe(e.key) end
      steps[#steps+1] = make_step(e, l)
    end
  end

  -- 4. Order for apply: phase first, then ID (stable output).
  table.sort(steps, function(a, b)
    if phase(a.action) ~= phase(b.action) then return phase(a.action) < phase(b.action) end
    return a.key < b.key
  end)
  return steps          -- data only: nothing changed. apply() runs the steps in this order.
end

function make_step(e, l)
  local c = classify(e.d, e.r, l, e.kind)
  return { key = e.key, action = e.kind.decide(c), desired = e.d, recorded = e.r, live = l }
end

function phase(action)  -- ADR 0054: free slots first, fill them last
  if action == "delete" or action == "forget"   then return 1 end
  if action == "create" or action == "recreate" then return 3 end
  return 2              -- update, adopt, noop, conflicts
end
```

Step by step:

+ `index_by` builds a table from ID to item, per kind: `D` for desired (all clauses from all specs),
  `R` for recorded (all entries in state). Two desired items with the same ID are an error, because
  two clauses cannot own the same resource.
+ `union(keys(D), keys(R))` is every ID of that kind that appears on either side, each once. Each
  becomes an entry. One of `d` and `r` is `nil` when the ID is on only one side. That is where
  `classify`'s `nil`s come from.
+ Entries with a record (kept or removed) are classified and decided first. Each one whose action is
  `delete` adds its slot to `freed`.
+ Then the new entries (desired only). Their live is observed, unless a delete in this plan frees
  their slot: then live is `nil`, because the delete runs first (step 4).
+ The steps are sorted: deletes and forgets, then updates and the rest, then creates; by ID within
  each phase. Same input, same plan.
+ The step keeps the values too, so `apply` and the plan output know what to do and what to show.

*Why the order of steps 2 and 3 matters.* A spec turns `~/.foo` from a link into a download. Without
step 2 first, the download would observe the old link still on disk, which ADR 0032 calls a
conflict. With it, the link's `delete` frees `fs:~/.foo`, the download sees it as absent and is a
`create`, and apply deletes before it creates. Only a `delete` frees a slot (ADR 0054). If the old
link was changed by hand, its step is a conflict and the plan stops there. There is no removal
policy that could turn the `delete` into a `forget` (ADR 0061).

*Two clauses of different kinds with the same slot* (situation A in ADR 0054) never reach `plan`:
the same-slot check (ADR 0021's same-`dst` check, for files) compares slots across kinds and fails
the plan first. Two items of the *same* kind and output have the same ID, so `index_by` catches them.

*ID and slot.* The ID says _what_ a resource is (`link:~/.foo`); matching uses it. The slot says
_where_ it is (`fs:~/.foo`); conflicts and freed places use it. `plan` only compares slots for
equality. It does not know what `fs` or `pacman` means, so it stays generic.

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

`index_by`, `union` and `keys` are not shown. They are ordinary table helpers.

= The default table

This is the generic table from `design.typ`. It is *not a fallback* (ADR 0058): no kind inherits
rows from it. It is the starting pattern for a new kind's table: copy it, then change the rows that
differ. It reads the case, top to bottom, in the three groups above:

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

Every kind writes its whole table (ADR 0058). There is no fallback, so a row nobody wrote cannot
silently become `update` or `delete`. In Rust it is a `match` on the two enums with no `_` arm: a
forgotten case is a compile error. Each impossible combination (the 7 cells outside "The 13
cases") gets `unreachable()`. Reaching one is a bug in `classify` or in a kind's comparisons, and it
panics, which is safe because planning has changed nothing yet.

The table for links (ADR 0030), also used by downloads (ADR 0057):

```lua
function links_like_decide(c)
  if c.desired == "new" then
    if c.live == "absent"   then return "create"   end
    if c.live == "desired"  then return "adopt"    end
    if c.live == "other"    then return "conflict" end
    if c.live == "recorded" or c.live == "both" then unreachable() end
  elseif c.desired == "removed" then
    if c.live == "absent"   then return "forget"   end
    if c.live == "recorded" then return "delete"   end
    if c.live == "other"    then return "conflict" end
    if c.live == "desired" or c.live == "both" then unreachable() end
  elseif c.desired == "match" then
    if c.live == "absent"   then return "recreate" end
    if c.live == "both"     then return "noop"     end
    if c.live == "other"    then return "conflict_drift" end
    if c.live == "desired" or c.live == "recorded" then unreachable() end
  elseif c.desired == "differ" then
    if c.live == "absent"   then return "recreate" end
    if c.live == "desired"  then return "adopt"    end
    if c.live == "recorded" then return "update"   end
    if c.live == "other"    then return "conflict_drift" end
    if c.live == "both"     then unreachable() end
  end
end
```

The rows where links differ from the generic table:

- *Recorded, live absent, still desired: `recreate`.* The user deleted the link by hand. Nothing at
  the path can be lost, so mdot makes it again.
- *Recorded, live absent, not desired: `forget`.* The spec dropped it and it is already gone. Only
  the record is removed.
- *The spec changed and disk already matches the new `src`: `adopt`.* Someone already did the
  update by hand. Only the record changes.

Checked by running it: with plain equality as all three comparisons, this gives ADR 0030's result
for all 13 cases.

= Downloads use the same table

With the download comparisons above (no `match_ld`), `links_like_decide` gives ADR 0032's result
for every row (checked by running it, ADR 0057):

#table(
  columns: (auto, auto, 1fr),
  [case],                          [action],          [ADR 0032 row],
  [new / absent],                  [create],          [create],
  [new / other],                   [conflict],        [present, no record: "unknown, run `mdot verify`"],
  [match / both],                  [noop],            [stat matches, `R == D`, same `mode`],
  [differ / recorded],             [update],          [`chmod` only, or download again (`update_detail`)],
  [match or differ / other],       [conflict_drift],  [stat differs: "changed, run `mdot verify`"],
  [match or differ / absent],      [recreate],        [absent: re-create, shown in the plan],
  [removed / recorded],            [delete],          [stat matches: delete],
  [removed / other],               [conflict],        [stat differs: conflict],
  [removed / absent],              [forget],          [absent: forget],
)

New / desired and differ / desired (the two adopt cases) are never reached, because downloads have
no `match_ld`. Those are the cases only a hash could answer, and `mdot verify` answers them.

*"Same / differ" is enough* (ADR 0057). The `chmod` and download-again rows are both an update, so
`decide` does not tell them apart. The step keeps `desired` and `recorded`, and the kind's
`update_detail` picks from them, for the plan output and for `apply`:

```lua
function download.update_detail(step)
  if step.desired.key ~= step.recorded.key then
    return "download again"                  -- content changed (R ≠ D)
  else
    return "chmod " .. step.desired.mode     -- only the mode changed
  end
end
```

= Testing

`classify` and every `decide` are pure functions. One test per row of a kind's table, with no
filesystem: build `d`, `r`, `l`, call `decide(classify(...))`, compare with the table. Only `observe`
and running an action touch the disk.

= Open

From ADR 0035:

- A separate library, or a module inside mdot with no mdot includes.
- Rust shape: a trait or an enum (ADR 0036 replaces ADR 0035's C++ wording).
- How the differently shaped values (an observation, a state record, a clause) are typed in Rust.
  ADR 0057 fixes only that there is one comparison per pair and that `match_ld` is optional.

From ADR 0058:

- How information that is not in the case reaches `decide`: a package's `installed_by_mdot`
  (ADR 0028) changes the answer for removed / recorded. The `on_remove` policy, which had the same
  problem, was dropped (ADR 0061).
