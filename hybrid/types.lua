local inspect = require("inspect")
local Class = require("hybrid.classic")

---@class Type : Class
---@field type_name string
local Type = Class:extend("Type")

---@class UnionType : Type
---@field types PrimitiveType[]
local UnionType = Type:extend("UnionType")

---@class PrimitiveType : Type
local PrimitiveType = Type:extend("PrimitiveType")

---@class MapType : Type
---@field schema table<string, Type>
local MapType = Type:extend("MapType")

---
---Given a list, returns the string `tostring(list[i])..sep..tostring(list[i+1]) ··· sep..tostring(list[j])`.
---All elements are first converted to strings using `tostring`, so numbers, tables with a `__tostring` metamethod,
---and other values are handled safely.
---
---@param list table
---@param sep? string
---@param i?   integer
---@param j?   integer
---@return string
---@nodiscard
local function concat_tostring(list, sep, i, j)
   i = i or 1
   j = j or #list
   sep = sep or ""

   local tmp = {}
   for k = i, j do
      tmp[#tmp + 1] = tostring(list[k])
   end

   return table.concat(tmp, sep, 1, #tmp)
end

---@param list table
---@param conj? string "default: 'and'"
---@return string
local function conjoin(list, conj)
   conj = conj or "and"
   if #list == 0 then
      return ""
   end
   if #list == 1 then
      return tostring(list[1])
   end

   local expected = concat_tostring(list, ", ", 1, #list - 1)
   return ("%s %s %s"):format(expected, conj, tostring(list[#list]))
end

---@param str any
---@param close string
local function enclose(str, close)
   assert(#close == 2, "close: '" .. close .. "'")
   return close:sub(1, 1) .. tostring(str) .. close:sub(2, 2)
end

---@param key any
local function enclose_key(key)
   if type(key) == "number" then
      return enclose(key, "[]")
   elseif type(key) == "string" then
      return enclose(key, "''")
   else
      return key
   end
end

---@param value any
---@param expected Type
local function assertIsClass(value, expected)
   assert(Class.isClass(value), ("expected Class subtype '%s', got '%s'"):format(expected.name, type(value)))
end

---@param value Type
---@param expected Type
local function assertIsInstance(value, expected)
   assert(value:is(expected), ("expected Class subtype %s, got %s"):format(expected, value))
end

---@param value any
---@param expected string
---@return string
local function string_expect(value, expected)
   if type(value) == "string" then
      value = enclose(value, "''")
   end
   return ("expected '%s', got '%s': %s"):format(expected, type(value), tostring(value))
end


---@param type_name string
function Type:initialize(type_name)
   self.type_name = type_name
end

---@return string
function Type:__tostring()
   return ("<abstract Type '%s'>"):format(self.type_name or "?")
end

---@param ... any
---@return boolean, any
function Type:__call(...)
   return false, "method '__call' is abstract and must be implemented by a subclass."
end

function UnionType:initialize(...)
   assert(select("#", ...) > 0, "cannot create an empty UnionType")

   Type.initialize(self, "union")
   self.types = {}
   self:add(...)
end

---@param value any
---@return boolean, any
function UnionType:__call(value)
   ---@type string[]
   local expected_types = {}
   for _, p_type in ipairs(self.types) do
      local ok, _ = p_type(value)
      if ok then
         return true, nil
      end
      table.insert(expected_types, p_type.type_name)
   end

   return false, string_expect(value, conjoin(expected_types, "or"))
end

---@param ... PrimitiveType
---@return UnionType
function UnionType:add(...)
   local types = { ... }
   for _, p_type in ipairs(types) do
      assertIsClass(p_type, PrimitiveType)
      table.insert(self.types, p_type)
   end
   return self
end

---@return string
function UnionType:__tostring()
   return conjoin(self.types, "or")
end

---@param type_name string
function PrimitiveType:initialize(type_name)
   Type.initialize(self, type_name)
end

---@return string
function PrimitiveType:__tostring()
   return "'" .. self.type_name .. "'"
end

---@param value any
---@return boolean, any
function PrimitiveType:__call(value)
   if self.type_name == "any" or type(value) == self.type_name then
      return true, nil
   else
      return false, string_expect(value, self.type_name)
   end
end

---@param schema table<string, Type>
function MapType:initialize(schema)
   assert(type(schema) == "table", string_expect(schema, "table"))
   for key, value in pairs(schema) do
      -- TODO: Maybe, allow non-Class values?
      assert(Class.isClass(value), ("field %s: %s"):format(enclose_key(key), string_expect(value, "type")))
   end
   Type.initialize(self, "map")
   self.schema = schema
end

---@param value any
---@return boolean, any
function MapType:__call(value)
   if type(value) ~= "table" then
      return false, string_expect(value, "table")
   end

   ---@type string[]
   local missing_keys = {}
   for key, _ in pairs(self.schema) do
      if value[key] == nil then
         table.insert(missing_keys, enclose_key(key))
      end
   end
   if #missing_keys > 0 then
      return false, "missing keys: " .. conjoin(missing_keys, "and")
   end

   for key, p_type in pairs(self.schema) do
      local ok, err = p_type(value[key])
      if not ok then
         return ok, ("field %s: %s"):format(enclose_key(key), err)
      end
   end
   return true, nil
end

---@class hybrid.types
---@field string PrimitiveType
---@field number PrimitiveType
---@field function PrimitiveType
---@field func PrimitiveType
---@field boolean PrimitiveType
---@field table PrimitiveType
local M = {
   string = PrimitiveType:new("string"),
   number = PrimitiveType:new("number"),
   func = PrimitiveType:new("function"),
   boolean = PrimitiveType:new("boolean"),
   userdata = PrimitiveType:new("userdata"),
   table = PrimitiveType:new("table"),
   null = PrimitiveType:new("nil"),
   any = PrimitiveType:new("any"),

   ---@param ... PrimitiveType
   ---@return UnionType
   union = function(...) return UnionType:new(...) end,
   ---@param schema table<string, Type>
   ---@return MapType
   map = function(schema) return MapType:new(schema) end,
}
M["function"] = M.func
M["nil"] = M.null

return M
