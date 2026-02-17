---@diagnostic disable: lowercase-global

function testUnionWithBuiltinTypes()
   ---@type Result, string
   local _, err

   local test

   test = t.union(t.string, t.number)
   _, err = test(1)
   lu.assertEquals(err, "")
   _, err = test("")
   lu.assertEquals(err, "")
   _, err = test(true)
   lu.assertEquals(err, "expected type string or number, got boolean: true")

   test = t.union(t.string, t.number, t.any)
   _, err = test(1)
   lu.assertEquals(err, "")
   _, err = test("")
   lu.assertEquals(err, "")
   _, err = test(true)
   lu.assertEquals(err, "")
   _, err = test(nil)
   lu.assertEquals(err, "")
end
