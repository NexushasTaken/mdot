local inspect = require("inspect")
local Class = require("hybrid.classic")
local dbg = require("debugger")
local utils = require("hybrid.utils")

---@class hybrid.types
local types = {}

---@class BaseType : Class
---@field _type_name string
local BaseType = Class:extend("BaseType")

---@class UnionType : BaseType
---@field _types BaseType[]
local UnionType = BaseType:extend("UnionType")

---@class BuiltinType : BaseType
local BuiltinType = BaseType:extend("BuiltinType")

---@class MapType : BaseType
---@field _schema table<string, BaseType>
local MapType = BaseType:extend("MapType")

---@class MapOfType : BaseType
---@field _paired_types [BaseType, BaseType][]
local MapOfType = BaseType:extend("MapOfType")

---@class OptionalType : BaseType
---@field _target_type BaseType
local OptionalType = Class:extend("OptionalType")

---@alias Result boolean | Error
---@class Error
local Error = {}

---@param value any
---@return string
local function describe_value(value)
   local t = type(value)
   if t == "boolean" or t == "number" or t == "table" or t == "function" then
      return tostring(value)
   elseif t == "string" then
      return utils.enclose(tostring(value), '""')
   end
   return ""
end

---@param value any
---@param expected_type BaseType
local function assertIsClass(value, expected_type)
   assert(Class.isClass(value), ("expected Class subtype of %s, got %s: %s"):format(expected_type, type(value), value))
end

---@param value BaseType
---@param expected_type BaseType
local function assertIsInstance(value, expected_type)
   assert(value:is(expected_type), ("expected Class subtype of %s, got %s"):format(expected_type, value))
end

---@param value any
---@param expected_type string
---@return string
local function string_expect(value, expected_type)
   if type(value) == "string" or type(value) == "function" then
      value = utils.enclose(value, "''")
   end
   return ("expected %s, got %s: %s"):format(expected_type, type(value), tostring(value))
end

---@param value any
---@param expected_type BaseType
local function expect_got_value(value, expected_type)
   local printable_value = describe_value(value)
   if #printable_value == 0 then
      return ("expected type %s, got %s"):format(expected_type:_describe_type(), type(value))
   else
      return ("expected type %s, got %s: %s"):format(expected_type:_describe_type(), type(value), printable_value)
   end
end

---@param _type_name string
function BaseType:initialize(_type_name)
   self._type_name = _type_name
end

---@return OptionalType
function BaseType:optional()
   return OptionalType:new(self)
end

---@return string
function BaseType:__tostring()
   return self.name or "BaseType"
end

---@return string
function BaseType:_describe_type()
   return "base_type"
end

---@param ... any
---@return boolean
function BaseType:accepts(...)
   return false
end

---@param value any
---@return Result, string
function BaseType:check(value)
   return false, ""
end

---@param ... any
---@return boolean, string
function BaseType:__call(...)
   return false, "method '__call' is abstract and must be implemented by a subclass."
end

---@param target_type BaseType
function OptionalType:initialize(target_type)
   BaseType.initialize(self, "optional")
   self._target_type = target_type
end

---@return string
function OptionalType:_describe_type()
   return self._type_name .. " " .. self._target_type:_describe_type()
end

---@return string
function OptionalType:__tostring()
   return self:_describe_type()
end

---@param value any
---@return Result, string
function OptionalType:check(value)
   if value == nil then
      return true, ""
   end

   local ok, _ = self._target_type(value)
   if ok then
      return true, ""
   else
      return Error, expect_got_value(value, self)
   end
end

---@param value any
---@return boolean, string
function OptionalType:__call(value)
   local ok, err = self:check(value)
   if ok == Error or not ok then
      return false, err
   else
      return true, ""
   end
end

---@param type_name string
function BuiltinType:initialize(type_name)
   BaseType.initialize(self, type_name)
end

---@return string
function BuiltinType:_describe_type()
   return self._type_name
end

---@return string
function BuiltinType:__tostring()
   return self:_describe_type()
end

---@param value any
---@return Result, string
function BuiltinType:check(value)
   if self._type_name == "any" or type(value) == self._type_name then
      return true, ""
   else
      return false, expect_got_value(value, self)
   end
end

---@param value any
---@return boolean, string
function BuiltinType:__call(value)
   local ok, err = self:check(value)
   if ok == Error or not ok then
      return false, err
   else
      return true, ""
   end
end

function UnionType:initialize(...)
   BaseType.initialize(self, "union")

   assert(select("#", ...) > 0, "cannot create an empty UnionType")
   self._types = {}
   self:add(...)
end

---@return string
function UnionType:_describe_type()
   return utils.conjoin(self._types, "or")
end

---@param ... BaseType
---@return UnionType
function UnionType:add(...)
   local base_types = { ... }
   for _, p_type in ipairs(base_types) do
      assertIsClass(p_type, BaseType)
      assertIsInstance(p_type, BaseType)
      table.insert(self._types, p_type)
   end
   return self
end

---@return string
function UnionType:__tostring()
   return self:_describe_type()
end

---@param value any
---@return Result, string
function UnionType:check(value)
   ---@type string[]
   local errors = {}
   for _, p_type in ipairs(self._types) do
      local ok, err = p_type:check(value)
      if ok == Error then
         table.insert(errors, err)
      elseif ok then
         return true, ""
      end
   end

   if #errors > 0 then
      return Error, utils.conjoin(errors, "or")
   else
      return false, expect_got_value(value, self)
   end
end

---@param value any
---@return boolean, string
function UnionType:__call(value)
   local ok, err = self:check(value)
   if ok == Error or not ok then
      return false, err
   else
      return true, ""
   end
end

---@param schema table<string, BaseType>
function MapType:initialize(schema)
   BaseType.initialize(self, "map")
   assert(type(schema) == "table", string_expect(schema, "table"))
   for key, value in pairs(schema) do
      -- TODO: Maybe, allow non-Class values?
      assert(Class.isClass(value), ("field %s: %s"):format(utils.enclose_key(key), string_expect(value, "BaseType")))
   end
   self._schema = schema
end

---@return string
function MapType:__tostring()
   return "BaseType" .. utils.enclose(self._type_name, "()")
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
   for key, _ in pairs(self._schema) do
      if value[key] == nil then
         table.insert(missing_keys, utils.enclose_key(key))
      end
   end
   if #missing_keys > 0 then
      return false, "missing keys: " .. utils.conjoin(missing_keys, "and")
   end

   for key, p_type in pairs(self._schema) do
      local ok, err = p_type(value[key])
      if not ok then
         return ok, ("field %s: %s"):format(utils.enclose_key(key), err)
      end
   end
   return true, ""
end

---@param ... [BaseType, BaseType]
function MapOfType:initialize(...)
   BaseType.initialize(self, "map_of")
   self._paired_types = { ... }
   for arg_idx, value in ipairs(self._paired_types) do
      -- TODO: maybe, this is too verbose?
      assert(type(value) == "table", ("argument %s: %s"):format(arg_idx, string_expect(value, "{BaseType, BaseType}")))
      assert(#value == 2,
         ("argument %s: expected %s, got {%s}"):format(arg_idx, "{BaseType, BaseType}",
            utils.concat_tostring(value, ", ")))
      for idx, element in ipairs(value) do
         assert(Class.isClass(element),
            ("argument %s(index[%s]): %s"):format(arg_idx, idx, string_expect(element, "BaseType")))
      end
   end
end

---@return string
function MapOfType:__tostring()
   ---@type string[]
   local types = {}
   for _, paired_type in pairs(self._paired_types) do
      table.insert(types, ("%s = %s"):format(tostring(paired_type[1]), tostring(paired_type[2])))
   end
   return utils.conjoin(types, "or")
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

   if utils.table_size(value) == 0 then
      return false, ("expected %s key-value pairs, got empty table"):format(tostring(self))
   end

   ---@type string[]
   local valid_key_types_list = {}
   for _, paired_type in pairs(self._paired_types) do
      table.insert(valid_key_types_list, tostring(paired_type[1]))
   end
   local valid_key_types = utils.conjoin(valid_key_types_list, "or")
   ---@type string[]
   local errors = {}
   local all_ok = true

   for k, v in pairs(value) do
      local matched = false
      for _, paired_type in pairs(self._paired_types) do
         local ok_k, _ = (paired_type[1])(k)
         if ok_k then
            matched = true
            local ok_v, err_v = (paired_type[2])(v)
            if not ok_v or ((paired_type[2]):accepts(v) and not ok_v) then
               all_ok = false
               table.insert(errors, ("field %s value: %s"):format(utils.enclose_key(k), err_v))
            end
            break -- key matched one type, no need to check other key types
         end
      end
      if not matched then
         all_ok = false
         table.insert(errors, ("field %s key: %s"):format(utils.enclose_key(k), string_expect(k, valid_key_types)))
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

types.string = BuiltinType:new("string")
types.number = BuiltinType:new("number")
types.func = BuiltinType:new("function")
types.boolean = BuiltinType:new("boolean")
types.userdata = BuiltinType:new("userdata")
types.table = BuiltinType:new("table")
types.null = BuiltinType:new("nil")
types.any = BuiltinType:new("any")

---@param ... BaseType
---@return UnionType
types.union = function(...) return UnionType:new(...) end
---@param schema table<string, BaseType>
---@return MapType
types.map = function(schema) return MapType:new(schema) end
---@param ... [BaseType, BaseType]
---@return MapOfType
types.map_of = function(...) return MapOfType:new(...) end

return types
