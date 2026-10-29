# Lua sandboxing 01: locals, globals, tables, metatables

This is the first of four lessons. The goal of the series is to understand Lua sandboxing
well enough to design one and to know where its holes are.

1. **Locals, globals, tables, metatables** (this lesson): the foundations.
2. Globals are a table: `_ENV` in Lua 5.4.
3. What's actually dangerous in the standard library.
4. Doing it in sol2: `sol::environment`.

Version checked: **Lua 5.4** (the one Conan gives mdot through sol2 3.5.0). Every example
here was run with `lua5.4`. Watch out: on this machine plain `lua` is **5.5**, which
changes how globals are declared, so test with `lua5.4`.

---

## 1. Mental model

Lua has one data structure, the **table**, and almost everything is built from it:
arrays, records, modules, objects, and also the set of global variables.

Think of a table as a C hash map that can use any value as a key (except `nil`). You never
hold the table itself. You hold a pointer to it, like a `struct map *`. Copying the
variable copies the pointer.

The two kinds of variables differ in where they live:

```
local y = 2      -- a slot in the function's stack frame, like a C local.
                 -- It is invisible outside its block, and nothing can look it up by name.

x = 1            -- NOT a variable slot. It is a store into a table:
                 --   <the globals table>["x"] = 1
```

That second line is the whole reason sandboxing in Lua is possible. **A global is just a
key in a table.** If you control which table a piece of code uses for its globals, you
control what that code can see. Lesson 2 covers how code gets connected to that table.
This lesson covers tables, and the metatables that change how a table answers lookups.

---

## 2. Key facts

### 2.1 Locals vs globals

 |                                 | `local x = 1`                                  | `x = 1`                                                                     |
 | ---                             | ---                                            | ---                                                                         |
 | Lives in                        | a register in the current function             | the globals table, under key `"x"`                                          |
 | Visible to                      | the rest of the block (and closures inside it) | every piece of code that shares that globals table                          |
 | Lookup cost                     | direct slot access                             | a hash lookup on every access                                               |
 | A name with no `local` in scope | (n/a)                                          | the compiler treats it as a global: reading gives `nil`, writing creates it |

The globals table can see itself under the name `_G`, so `_G.x` and `x` are the same thing
by default (verified: `_G._G == _G` is `true`).

Two consequences you should remember:

- **A typo creates a global silently.** `local count = 0; cuont = 5` makes a new global
  `cuont` and leaves `count` alone. Lua doesn't warn.
- **Reading an undefined name gives `nil`, not an error.** `print(nonexistent)` prints
  `nil`.

### 2.2 Functions are values, and `function` is sugar

```lua
function greet() end          -- is exactly:  greet = function() end      (a global)
local function greet() end    -- is a local
function shapes.circle() end  -- is exactly:  shapes.circle = function() end
```

The last line stores a function in the field of an *existing* table `shapes`. If `shapes`
doesn't exist, you get an "attempt to index a nil value" error. So `function file.link()`
needs a table named `file` to already exist.

### 2.3 Tables

```lua
local t = {}            -- empty table
local p = {x = 1, y = 2}
p.x                     -- same as p["x"]; dot is sugar for a string key
local arr = {"a", "b"}  -- arr[1] == "a", arr[2] == "b"  (1-based!)
#arr                    -- 2, the length of the array part
```

**Reference semantics** (verified): `local a = {n=1}; local b = a; b.n = 2` changes `a.n`
to `2`. There is one table and two names for it. This matters for sandboxing: if you put
a table into a sandbox, the sandbox can change *that same table*.

### 2.4 Metatables: changing how a table behaves

Every table can have a **metatable**: a second, ordinary table whose specially named keys
(*metamethods*, all starting with `__`) tell Lua what to do in cases the table can't
handle on its own. It's similar to a C struct holding a vtable pointer, except the vtable
is optional and can be swapped at runtime.

```lua
setmetatable(t, mt)   -- attach mt to t (returns t)
getmetatable(t)       -- read it back
```

The two metamethods that matter for sandboxing:

**`__index`: what to do when a key is missing.** Lua runs it only when a read finds
nothing (the raw value is `nil`). If the key exists, Lua never consults it.

```lua
local defaults = {color = "red"}
local t = setmetatable({}, {__index = defaults})
t.color             --> "red"   (missing in t, found in defaults)
rawget(t, "color")  --> nil     (it really isn't in t)
t.color = "blue"    -- writes into t, defaults is untouched
t.color             --> "blue"  (now present, __index no longer consulted)
```

`__index` can be a **table** (look there next) or a **function** `(tbl, key) -> value`
(compute an answer). With a table, lookups chain: if `defaults` has its own `__index`, the
search continues (verified with a three-level chain).

**`__newindex`: what to do when assigning to a missing key.** It also fires only for keys
that are *absent*. Once a key exists, assignments go straight in (verified: `w.a = 1;
w.a = 2; w.b = 3` called `__newindex` for `a` and `b`, not for the second `a`).

**`rawget(t, k)` / `rawset(t, k, v)`** read and write while *skipping* metamethods. They're
the escape hatch, and a script that has them can get around your `__index`/`__newindex`
logic.

**`__metatable`: lock the metatable.** If the metatable has this field, `getmetatable`
returns that value instead of the real metatable, and `setmetatable` raises an error
(verified: `"cannot change a protected metatable"`).

### 2.5 Strings have a shared metatable

`("abc"):upper()` works because *all strings share one metatable* whose `__index` is the
`string` library table (verified: `getmetatable("").__index == string`). Keep this in mind
for lesson 2: it is state shared by every piece of code in the same Lua state, and you
can't easily give each piece its own copy.

---

## 3. Misconceptions

| Misconception | Correct view |
|---|---|
| "`x = 1` declares a variable." | It stores the key `"x"` into the current globals table. |
| "Undefined variables are errors." | Reading gives `nil`, and writing creates a global. Both are silent. |
| "Assigning a table copies it." | It copies the reference. Both names see every change. |
| "`__index` runs on every read." | Only when the key is missing from the table itself. |
| "`__newindex` intercepts every write." | Only writes to missing keys. After the first write, the key exists. |
| "A metatable makes a table read-only." | Only if you design it that way, and `rawset` still gets around it unless the code can't reach `rawset`. |

---

## 4. Sources

- *Lua 5.4 Reference Manual*: §2.1 (values and types, tables), §2.2 (environments and the
  global environment), §2.4 (metatables and metamethods), §6.1 (`getmetatable`,
  `setmetatable`, `rawget`, `rawset`). <https://www.lua.org/manual/5.4/>
- *Programming in Lua* (4th ed., Roberto Ierusalimschy): chapters on tables and on
  metatables. Highly readable.
- All "verified" claims: a scratch script run with `lua5.4` (5.4.9) on this machine.

---

## 5. Check questions (answer in chat, optional)

1. `local t = setmetatable({}, {__index = _G})`. What does `t.print` give you, and is
   `print` stored *inside* `t`?
2. Using the same `t`, after `t.print = nil`, what does `t.print` give you? Why?
3. Without running it, which of these lines create a global?
   `local a = 1` / `b = 2` / `function c() end` / `local function d() end`
