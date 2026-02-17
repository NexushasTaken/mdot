---@diagnostic disable: lowercase-global
local t = require("hybrid.types")

function testBuiltinTypes()
   ---@type Result, string
   local _, err

   _, err = t.string("")
   lu.assertEquals(err, "")
   _, err = t.string(1)
   lu.assertEquals(err, "expected type string, got number: 1")

   _, err = t.number(0)
   lu.assertEquals(err, "")
   _, err = t.number("")
   lu.assertEquals(err, "expected type number, got string: \"\"")

   _, err = t.func(function() end)
   lu.assertEquals(err, "")
   _, err = t.func(1)
   lu.assertEquals(err, "expected type function, got number: 1")

   _, err = t.boolean(true)
   lu.assertEquals(err, "")
   _, err = t.boolean(1)
   lu.assertEquals(err, "expected type boolean, got number: 1")

   _, err = t.table({})
   lu.assertEquals(err, "")
   _, err = t.table(1)
   lu.assertEquals(err, "expected type table, got number: 1")

   _, err = t.null(nil)
   lu.assertEquals(err, "")
   _, err = t.null(1)
   lu.assertEquals(err, "expected type nil, got number: 1")

   for _, value in ipairs({ "", 1, function() end, true, {}, nil }) do
      _, err = t.any(value)
      lu.assertEquals(err, "")
   end

   -- userdata = BuiltinType:new("userdata"), -- ?
end

function testBuiltinTypesOptional()
   ---@type Result, string
   local _, err

   _, err = t.string:optional()("")
   lu.assertEquals(err, "")
   _, err = t.string:optional()(nil)
   lu.assertEquals(err, "")
   _, err = t.string:optional()(1)
   lu.assertEquals(err, "expected type string, got number: 1")

   _, err = t.number:optional()(0)
   lu.assertEquals(err, "")
   _, err = t.number:optional()(nil)
   lu.assertEquals(err, "")
   _, err = t.number:optional()("")
   lu.assertEquals(err, "expected type number, got string: \"\"")

   _, err = t.func:optional()(function() end)
   lu.assertEquals(err, "")
   _, err = t.func:optional()(nil)
   lu.assertEquals(err, "")
   _, err = t.func:optional()(1)
   lu.assertEquals(err, "expected type function, got number: 1")

   _, err = t.boolean:optional()(true)
   lu.assertEquals(err, "")
   _, err = t.boolean:optional()(nil)
   lu.assertEquals(err, "")
   _, err = t.boolean:optional()(1)
   lu.assertEquals(err, "expected type boolean, got number: 1")

   _, err = t.table:optional()({})
   lu.assertEquals(err, "")
   _, err = t.table:optional()(nil)
   lu.assertEquals(err, "")
   _, err = t.table:optional()(1)
   lu.assertEquals(err, "expected type table, got number: 1")

   _, err = t.null:optional()(nil)
   lu.assertEquals(err, "")
   _, err = t.null:optional()(1)
   lu.assertEquals(err, "expected type nil, got number: 1")

   for _, value in ipairs({ "", 1, function() end, true, {}, nil }) do
      _, err = t.any(value)
      lu.assertEquals(err, "")
   end

   -- userdata = BuiltinType:new("userdata"), -- ?
end
