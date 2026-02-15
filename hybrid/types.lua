local Class = require("hybrid.classic")

---@class Type : Class
---@field type_name string
local Type = Class:extend()

---@class UnionType : Type
---@field types PrimitiveType[]
local UnionType = Type:extend()

---@class PrimitiveType : Type
local PrimitiveType = Type:extend()

---@class DictType : Type
---@field schema table<string, Type>
local DictType = Type:extend()


---@param value Class
---@param expected Class
local function check_type(value, expected)
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

---@param ... PrimitiveType
---@return UnionType
local function union(...)
   return UnionType:new(...)
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
      check_type(p_type, PrimitiveType)
      table.insert(self.types, p_type)
   end
   return self
end

---@param type_name string
function PrimitiveType:initialize(type_name)
   Type.initialize(self, type_name)
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
---@return DictType
local function dict(schema)
   return DictType:new(schema)
end

---@param schema table<string, Type>
function DictType:initialize(schema)
   check_type(schema, PrimitiveType:new("table")) -- TODO: check if the values of schema is Type, not just checking if it's a table.
   Type.initialize(self, "dict")
   self.schema = schema
end

---@param value any
function DictType:__call(value)
   check_type(value, PrimitiveType:new("table"))

   for key, p_type in pairs(self.schema) do
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

   union = union,
   dict = dict,
}
M["function"] = M.func
M["nil"] = M.null

return M
