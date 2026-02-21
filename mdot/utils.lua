local log = require("mdot.log")
local M = {}

---Wraps a value in a table if it isn't already one.
---@generic T
---@param value T | T[] The value to check.
---@param default? T[] The value to return if `value` is nil.
---@return T[]
function M.as_list(value, default)
   if value == nil then
      return default or {}
   end

   if type(value) ~= "table" then
      return { value }
   end

   return value
end

---@param err any
M.throw_err = function(err)
   log:error(err)
   os.exit(1)
end

---@param ok string
---@param err any
M.throw = function(ok, err)
   if not ok then
      log:error(err)
      os.exit(1)
   end
end

return M
