-- The sandbox (design.typ "Loading and sandbox", ADR 0013, 0048, 0078).
--
-- This file runs once, in the full Lua state, before any user file. User files
-- never see its locals: each one runs in a fresh table that new_env() builds,
-- holding only what is listed here. Purity, not security, is the goal.
--
-- Called from sandbox.rs as:  local M = <this chunk>(os, dirs, dir_names, write_line)

local os_facts, dirs_facts, dir_names, write_line = ...

-- Capture what we need now; later code must not depend on user-visible globals.
local _G, error, next, pairs, ipairs, select, type, tostring, setmetatable, getmetatable =
      _G, error, next, pairs, ipairs, select, type, tostring, setmetatable, getmetatable
local math_type, concat, unpack = math.type, table.concat, table.unpack

local M = {}

-- A read-only view of `t`. Reads go to `t`; any write is an error that names
-- the field. `__metatable = false` makes getmetatable() return false and
-- setmetatable() fail, so a file cannot unwrap the proxy (there is no rawset).
--
--   opts.fields  set of allowed keys; reading any other key is an error
--   opts.deep    nested tables are wrapped too (for mdot.vars), and # works
--
-- Without opts.deep, `next(proxy)` is nil and `#proxy` is 0: the known quirk
-- in design.typ. pairs() works through __pairs.
local function readonly(t, name, opts)
  opts = opts or {}
  local function wrap(k, v)
    if opts.deep and type(v) == "table" then
      return readonly(v, name .. "." .. tostring(k), opts)
    end
    return v
  end
  local mt = {
    __index = function(_, k)
      if opts.fields and not opts.fields[k] then
        error(("unknown field %s.%s"):format(name, tostring(k)), 2)
      end
      return wrap(k, t[k])
    end,
    __newindex = function(_, k)
      error(("cannot set %s.%s"):format(name, tostring(k)), 2)
    end,
    __pairs = function()
      local function iter(_, k)
        local nk, nv = next(t, k)
        return nk, wrap(nk, nv)
      end
      return iter, nil, nil
    end,
    __metatable = false,
  }
  if opts.deep then
    mt.__len = function() return #t end
  end
  return setmetatable({}, mt)
end

local function set_of(list)
  local s = {}
  for _, v in ipairs(list) do s[v] = true end
  return s
end

-- Libraries ---------------------------------------------------------------

-- `string` without `dump`. Also used as the metatable index of every string,
-- so ("x"):upper() works and ("x").dump is nil.
local safe_string = {}
for k, v in pairs(string) do
  if k ~= "dump" then safe_string[k] = v end
end
local string_mt = getmetatable("")
string_mt.__index = safe_string
-- getmetatable("") now returns this marker instead of the real metatable, so
-- the real string table cannot be reached through a string value.
string_mt.__metatable = "locked"

local LIBS = {
  string = readonly(safe_string, "string"),
  table = readonly(table, "table"),
  math = readonly(math, "math"),
  utf8 = readonly(utf8, "utf8"),
}

local BASE = {
  "pairs", "ipairs", "next", "select", "type", "tostring", "tonumber", "error",
  "assert", "pcall", "setmetatable", "getmetatable",
}

-- Clauses -----------------------------------------------------------------
--
-- A clause is a table with clause_mt as its metatable. Only these functions
-- set it, and getmetatable() on it returns false, so a file cannot forge one.
-- sandbox.rs recognises clauses by comparing metatables.

local clause_mt = { __metatable = false }
M.clause_mt = clause_mt

local function clause(t)
  return setmetatable(t, clause_mt)
end

local function is_index(k, n)
  return math_type(k) == "integer" and k >= 1 and k <= n
end

-- file.link(src, dst) or file.link { names..., into = dir, dot? } (ADR 0022).
-- The batch form returns a plain list of link clauses; spec{} flattens lists.
local function file_link(...)
  local n = select("#", ...)
  local a, b = ...
  if n == 2 and type(a) == "string" and type(b) == "string" then
    return clause { kind = "link", src = a, dst = b }
  end
  if n == 1 and type(a) == "table" and getmetatable(a) == nil then
    local count = #a
    for k, v in pairs(a) do
      if k == "into" then
        if type(v) ~= "string" then error("file.link: `into` must be a string", 2) end
      elseif k == "dot" then
        if type(v) ~= "boolean" then error("file.link: `dot` must be a boolean", 2) end
      elseif is_index(k, count) then
        if type(v) ~= "string" then
          error(("file.link: name %d must be a string"):format(k), 2)
        end
      else
        error(("file.link: unknown field %s"):format(tostring(k)), 2)
      end
    end
    if a.into == nil then error("file.link: the batch form needs `into`", 2) end
    local prefix = a.into .. (a.dot and "/." or "/")
    local out = {}
    for i = 1, count do
      out[i] = clause { kind = "link", src = a[i], dst = prefix .. a[i] }
    end
    return out
  end
  error("file.link: expected file.link(src, dst) or file.link { names..., into = dir }", 2)
end

-- depends(names...) (ADR 0019).
local function depends(...)
  local names = { ... }
  for i = 1, select("#", ...) do
    if type(names[i]) ~= "string" then
      error(("depends: argument %d must be a string"):format(i), 2)
    end
  end
  return clause { kind = "depends", names = names }
end

-- spec { ... } only checks that it got a table. Flattening and checking each
-- entry happens in sandbox.rs, after the file has returned.
local function spec(t)
  if type(t) ~= "table" then error("spec: expected a table: spec { ... }", 2) end
  return t
end

local FILE = readonly({ link = file_link }, "file", { fields = { link = true } })

-- mdot global (ADR 0038, 0040, 0043, 0078) -------------------------------

local OS_FIELDS = set_of { "name", "family", "arch", "bitness", "distribution", "version",
                           "codename", "edition", "hostname" }
local OS = readonly(os_facts, "mdot.os", { fields = OS_FIELDS })
local DIRS = readonly(dirs_facts, "mdot.dirs", { fields = set_of(dir_names) })

-- mdot.print: tostring each value, join with a tab. write_line (Rust) adds
-- "<path>:<line>: " from the caller's position and writes it to stdout.
local function mdot_print(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring((select(i, ...)))
  end
  write_line(concat(parts, "\t"))
end

local MDOT_FIELDS = set_of { "os", "dirs", "vars", "print" }

-- role is "config", "host" or "spec". config.lua and the host file write
-- mdot.vars directly (the schema check runs afterwards, in Rust); a spec only
-- gets a deep read-only view.
local function make_mdot(role, vars)
  if role == "spec" then
    vars = readonly(vars, "mdot.vars", { deep = true })
  end
  return readonly({ os = OS, dirs = DIRS, vars = vars, print = mdot_print }, "mdot",
                  { fields = MDOT_FIELDS })
end

-- A fresh environment for one file (ADR 0048).
function M.new_env(role, vars)
  local env = {}
  for _, name in ipairs(BASE) do env[name] = _G[name] end
  for name, lib in pairs(LIBS) do env[name] = lib end
  env.spec = spec
  env.file = FILE
  env.depends = depends
  env.mdot = make_mdot(role, vars)
  return env
end

return M
