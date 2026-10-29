-- The sandbox (design.typ "Loading and sandbox", ADR 0013, 0048, 0078).
--
-- This file runs once, in the full Lua state, before any user file. User files
-- never see its locals: each one runs in a fresh table that new_env() builds,
-- holding only what is listed here. Purity, not security, is the goal.
--
-- Called from sandbox.rs as:
--   local M = <this chunk>(os, dirs, dir_names, write_line, spec, file_link, depends)
-- The last three are the clause constructors, written in Rust (clause.rs).

local os_facts, dirs_facts, dir_names, write_line, spec, file_link, depends = ...

-- Capture what we need now; later code must not depend on user-visible globals.
local _G, error, next, pairs, ipairs, select, type, tostring, setmetatable, getmetatable =
      _G, error, next, pairs, ipairs, select, type, tostring, setmetatable, getmetatable
local concat = table.concat

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
-- spec, file_link and depends come from Rust (clause.rs). They check their
-- arguments and return userdata that only sandbox.rs can read.

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
