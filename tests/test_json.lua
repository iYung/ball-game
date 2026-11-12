-- test_json.lua — unit tests for lua/util/json.lua

local JSON = require("lua/util/json")

-- 1. Simple object with number, boolean, null
local t = JSON.decode('{"a":1,"b":true,"c":null}')
assert(t.a == 1,    "object number")
assert(t.b == true, "object boolean")
assert(t.c == nil,  "object null -> nil")

-- 2. Nested array
local arr = JSON.decode("[[1,2],[3,4]]")
assert(arr[1][1] == 1, "nested array [1][1]")
assert(arr[1][2] == 2, "nested array [1][2]")
assert(arr[2][1] == 3, "nested array [2][1]")
assert(arr[2][2] == 4, "nested array [2][2]")

-- 3. String with escape sequence
local s = JSON.decode('{"s":"hello\\nworld"}')
assert(s.s == "hello\nworld", "string escape \\n: got " .. tostring(s.s))

-- 4. Number with exponent
local n = JSON.decode('{"n":1.5e2}')
assert(n.n == 150, "exponent number: got " .. tostring(n.n))

print("ALL TESTS PASSED")
