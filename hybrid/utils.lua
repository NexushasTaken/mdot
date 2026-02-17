local utils = {}

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
function utils.concat_tostring(list, sep, i, j)
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
function utils.conjoin(list, conj)
   conj = conj or "and"
   if #list == 0 then
      return ""
   end
   if #list == 1 then
      return tostring(list[1])
   end

   local expected = utils.concat_tostring(list, ", ", 1, #list - 1)
   return ("%s %s %s"):format(expected, conj, tostring(list[#list]))
end

---@param str any
---@param close string
function utils.enclose(str, close)
   assert(#close == 2, "delimiter must be 2 characters")
   return close:sub(1, 1) .. tostring(str) .. close:sub(2, 2)
end

---@param key any
function utils.enclose_key(key)
   if type(key) == "number" then
      return utils.enclose(key, "[]")
   elseif type(key) == "string" or type(key) == "boolean" then
      return utils.enclose(key, "''")
   else
      return key
   end
end

---@param t table
---@return number
function utils.table_size(t)
   local count = 0
   for _ in pairs(t) do
      count = count + 1
   end
   return count
end

return utils
