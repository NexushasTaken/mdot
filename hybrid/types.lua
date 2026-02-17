local inspect = require("inspect")
local Class = require("hybrid.classic")
local dbg = require("debugger")

---@class Type : Class
---@field type_name string
---@field is_optional boolean
local Type = Class:extend("Type")

---@class UnionType : Type
---@field types Type[]
local UnionType = Type:extend("UnionType")

---@class PrimitiveType : Type
local PrimitiveType = Type:extend("PrimitiveType")

---@class MapType : Type
---@field schema table<string, Type>
local MapType = Type:extend("MapType")

---@class MapOfType : Type
---@field paired_types [Type, Type][]
local MapOfType = Type:extend("MapOfType")

---
---Given a list, returns the string `tostring(list[i])..sep..tostring(list[i+1]) ··· sep..tostring(list[j])`.
---All elements are first converted to strings using `tostring`, so numbers, tables with a `__tostring` metamethod,
---and other values are handled safely.
---
---@param list any[]
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

---@param list any[]
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
   assert(#close == 2, "delimiter must be 2 characters")
   return close:sub(1, 1) .. tostring(str) .. close:sub(2, 2)
end

---@param key any
local function enclose_key(key)
   if type(key) == "number" then
      return enclose(key, "[]")
   elseif type(key) == "string" or type(key) == "boolean" then
      return enclose(key, "''")
   else
      return key
   end
end

---@param t table
---@return number
local function table_size(t)
   local count = 0
   for _ in pairs(t) do
      count = count + 1
   end
   return count
end

---@param value any
---@param expected_type Type
local function assertIsClass(value, expected_type)
   assert(Class.isClass(value), ("expected Class subtype of %s, got %s: %s"):format(expected_type, type(value), value))
end

---@param value Type
---@param expected_type Type
local function assertIsInstance(value, expected_type)
   assert(value:is(expected_type), ("expected Class subtype of %s, got %s"):format(expected_type, value))
end

---@param value any
---@param expected_type string
---@return string
local function string_expect(value, expected_type)
   if type(value) == "string" or type(value) == "function" then
      value = enclose(value, "''")
   end
   return ("expected %s, got %s: %s"):format(expected_type, type(value), tostring(value))
end


---@param type_name string
function Type:initialize(type_name)
   self.type_name = type_name
   self.is_optional = false
end

---@generic T
---@param self T
---@return T
function Type:optional()
   self.is_optional = true
   return self
end

---@return string
function Type:__tostring()
   return self.name or "Type"
end

---@param ... any
---@return boolean
function Type:accepts(...)
   return false
end

---@param ... any
---@return boolean, string
function Type:__call(...)
   return false, "method '__call' is abstract and must be implemented by a subclass."
end

function UnionType:initialize(...)
   Type.initialize(self, "union")

   assert(select("#", ...) > 0, "cannot create an empty UnionType")
   self.types = {}
   self:add(...)
end

---@param ... PrimitiveType
---@return UnionType
function UnionType:add(...)
   local types = { ... }
   for _, p_type in ipairs(types) do
      assertIsClass(p_type, Type)
      assertIsInstance(p_type, Type)
      table.insert(self.types, p_type)
   end
   return self
end

---@return string
function UnionType:__tostring()
   return conjoin(self.types, "or")
end

---@param value any
---@return boolean, string | string[]
function UnionType:__call(value)
   ---@type string[]
   local errors = {}
   for _, p_type in ipairs(self.types) do
      local ok, err = p_type(value)
      if ok then
         return true, ""
      elseif p_type:accepts(value) then
         table.insert(errors, err)
      end
   end

   if #errors == 1 then
      return false, errors[1]
   elseif #errors > 1 then
      return false, errors
   else
      return false, string_expect(value, conjoin(self.types, "or"))
   end
end

---@param type_name string
function PrimitiveType:initialize(type_name)
   Type.initialize(self, type_name)
end

---@return string
function PrimitiveType:__tostring()
   return "Type" .. enclose(self.type_name, "()")
end

---@param value any
---@return boolean
function PrimitiveType:accepts(value)
   return self.type_name == "any" or type(value) == self.type_name
end

---@param value any
---@return boolean, string
function PrimitiveType:__call(value)
   if self:accepts(value) or (self.is_optional and value == nil) then
      return true, ""
   else
      return false, string_expect(value, self.type_name)
   end
end

---@param schema table<string, Type>
function MapType:initialize(schema)
   Type.initialize(self, "map")
   assert(type(schema) == "table", string_expect(schema, "table"))
   for key, value in pairs(schema) do
      -- TODO: Maybe, allow non-Class values?
      assert(Class.isClass(value), ("field %s: %s"):format(enclose_key(key), string_expect(value, "Type")))
   end
   self.schema = schema
end

---@return string
function MapType:__tostring()
   return "Type" .. enclose(self.type_name, "()")
end

---@param value any
---@return boolean
function MapType:accepts(value)
   return type(value) == "table"
end

---@param value any
---@return boolean, string
function MapType:__call(value)
   if not self:accepts(value) then
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
   return true, ""
end

---@param ... [Type, Type]
function MapOfType:initialize(...)
   Type.initialize(self, "map_of")
   self.paired_types = { ... }
   for arg_idx, value in ipairs(self.paired_types) do
      -- TODO: maybe, this is too verbose?
      assert(type(value) == "table", ("argument %s: %s"):format(arg_idx, string_expect(value, "{Type, Type}")))
      assert(#value == 2,
         ("argument %s: expected %s, got {%s}"):format(arg_idx, "{Type, Type}", concat_tostring(value, ", ")))
      for idx, element in ipairs(value) do
         assert(Class.isClass(element),
            ("argument %s(index[%s]): %s"):format(arg_idx, idx, string_expect(element, "Type")))
      end
   end
end

---@return string
function MapOfType:__tostring()
   ---@type string[]
   local types = {}
   for _, paired_type in pairs(self.paired_types) do
      table.insert(types, ("%s = %s"):format(tostring(paired_type[1]), tostring(paired_type[2])))
   end
   return conjoin(types, "or")
end

---@param value any
---@return boolean
function MapOfType:accepts(value)
   return type(value) == "table"
end

---@param value any
---@return boolean, string | string[]
function MapOfType:__call(value)
   if not self:accepts(value) then
      return false, string_expect(value, "table")
   end

   if table_size(value) == 0 then
      return false, ("expected %s key-value pairs, got empty table"):format(tostring(self))
   end

   ---@type string[]
   local valid_key_types_list = {}
   for _, paired_type in pairs(self.paired_types) do
      table.insert(valid_key_types_list, tostring(paired_type[1]))
   end
   local valid_key_types = conjoin(valid_key_types_list, "or")
   ---@type string[]
   local errors = {}
   local all_ok = true

   for k, v in pairs(value) do
      local matched = false
      for _, paired_type in pairs(self.paired_types) do
         local ok_k, _ = (paired_type[1])(k)
         if ok_k then
            matched = true
            local ok_v, err_v = (paired_type[2])(v)
            if not ok_v or ((paired_type[2]):accepts(v) and not ok_v) then
               all_ok = false
               table.insert(errors, ("field %s value: %s"):format(enclose_key(k), err_v))
            end
            break -- key matched one type, no need to check other key types
         end
      end
      if not matched then
         all_ok = false
         table.insert(errors, ("field %s key: %s"):format(enclose_key(k), string_expect(k, valid_key_types)))
      end
   end

   if all_ok then
      return true, ""
   elseif #errors == 1 then
      return false, errors[1]
   elseif #errors > 1 then
      return false, errors
   else
      return false, string_expect(value, valid_key_types)
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

   ---@param ... Type
   ---@return UnionType
   union = function(...) return UnionType:new(...) end,
   ---@param schema table<string, Type>
   ---@return MapType
   map = function(schema) return MapType:new(schema) end,
   ---@param ... [Type, Type]
   ---@return MapOfType
   map_of = function(...) return MapOfType:new(...) end,
}
M["function"] = M.func
M["nil"] = M.null

return M
