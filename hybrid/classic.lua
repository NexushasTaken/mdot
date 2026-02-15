--
-- classic
--
-- Copyright (c) 2014, rxi
--
-- This module is free software; you can redistribute it and/or modify it under
-- the terms of the MIT license. See LICENSE for details.
--


---@class Class
---@field super? Class
---@field name string
local Class = {}
Class.__index = Class

--- Instance initializer. Override this in subclasses to set up instance fields.
--- Note: this is called by `:new(...)` on the created instance.
---@generic T
---@param self T
---@param ... any
function Class:initialize(...) end

--- Creates a new instance of the class and calls `:initialize(...)`.
--- Using generics so `SomeSubclass:new()` returns the concrete subclass type `T`.
---@generic T
---@param self T
---@param ... any
---@return T
function Class:new(...)
   local obj = setmetatable({}, self)
   -- call the instance initializer; subclasses override initialize
   if obj.initialize then
      obj:initialize(...)
   end
   return obj
end

--- Creates a subclass that inherits from this class.
--- Copies metamethods (names starting with "__") so special behavior is inherited.
---@generic T
---@param self T
---@param name? string
---@return T
function Class:extend(name)
   local cls = {}
   for k, v in pairs(self) do
      if k:find("^__") then
         cls[k] = v
      end
   end
   cls.__index = cls
   cls.super = self
   cls.name = name or "Class"
   setmetatable(cls, self)
   return cls
end

--- Implements methods from other classes (mixins).
---@param self Class
---@param ... Class
function Class:implement(...)
   for _, mix in pairs({ ... }) do
      for k, v in pairs(mix) do
         if self[k] == nil and type(v) == "function" then
            self[k] = v
         end
      end
   end
end

--- Checks if this object is an instance of class T or its subclasses.
---@param self any
---@param T Class
---@return boolean
function Class:is(T)
   local mt = getmetatable(self)
   while mt do
      if mt == T then
         return true
      end
      mt = getmetatable(mt)
   end
   return false
end

--- String representation of the class.
---@param self Class
---@return string
function Class:__tostring()
   return self.name
end

return Class
