local Class = require("hybrid.classic")

---@class Type : Class
---@field type_name string
local Type = Class:extend("Type")

---@class UnionType : Type
---@field types PrimitiveType[]
local UnionType = Type:extend("UnionType")

---@class PrimitiveType : Type
local PrimitiveType = Type:extend("PrimitiveType")

---@class DictType : Type
---@field schema table<string, Type>
local DictType = Type:extend("DictType")

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

---@param value any
---@param expected Type
local function assertIsClass(value, expected)
   assert(expected.isClass(value), ("expected type %s, got %s"):format(expected.name, type(value)))
end

---@param value Type
---@param expected Type
local function assertIsInstance(value, expected)
   assert(value:is(expected), ("expected type %s, got %s"):format(expected, value))
end

---@param value any
---@param expected string
---@return string
local function string_expect(value, expected)
   return ("expected %s, got '%s': %s"):format(expected, type(value), value)
end

---@param value any
---@param types string[]
---@return string
local function string_expect_types(value, types)
   if #types == 1 then
      return string_expect(value, types[1])
   end

   local expected = "'" .. table.concat(types, ", ", 1, #types - 1)
   expected = expected .. " or '" .. types[#types] .. "'"
   return string_expect(value, expected)
end


---@param type_name string
function Type:initialize(type_name)
   self.type_name = type_name
end

---@return string
function Type:__tostring()
   return ("<abstract Type '%s'>"):format(self.type_name or "?")
end

function UnionType:initialize(...)
   Type.initialize(self, "union")
   self.types = {}
   if select("#", ...) > 0 then
      self:add(...)
   end
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

   return false, string_expect_types(value, expected_types)
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
   if #self.types == 1 then
      return tostring(self.types[1])
   end

   local expected = concat_tostring(self.types, ", ", 1, #self.types - 1)
   return expected .. " or " .. tostring(self.types[#self.types])
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
function DictType:initialize(schema)
   assertIsInstance(schema, PrimitiveType:new("table")) -- TODO: check if the values of schema is Type, not just checking if it's a table.
   Type.initialize(self, "dict")
   self.schema = schema
end

---@param value any
function DictType:__call(value)
   assertIsInstance(value, PrimitiveType:new("table"))

   for key, p_type in pairs(self.schema) do
      -- TODO: implement
   end
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
   ---@return DictType
   dict = function(schema) return DictType:new(schema) end,
}
M["function"] = M.func
M["nil"] = M.null

return M
