require("lua/headless/stubs")
local DefParser = require("lua/game/def_parser")

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function ok(text, want)
    local got, err = DefParser.parse(text)
    assert(got, "should parse: " .. text .. " (" .. tostring(err) .. ")")
    assert(same(got, want), "wrong result for: " .. text)
end

local function bad(text, why)
    local got, err = DefParser.parse(text)
    assert(got == nil and type(err) == "string", "should be rejected: " .. (why or tostring(text)))
end

ok("{}", {})
ok("return {};", {})
ok("  return{ a = 1, b = -2.5; c = 1e+3, d = 2E-1, e = 0x10, }", {a=1, b=-2.5, c=1000, d=0.2, e=16})
ok("{ 1, {2, 3}, true, false, nil }", {1, {2, 3}, true, false})
ok("{ [\"a b\"] = 'x', ['c'] = \"y\", truex = false }", {["a b"]="x", c="y", truex=false})
ok("-- head\n--[[ block\n ]] return --[==[ x ]==] { a=1 } -- tail", {a=1})
ok([[{ "\a\b\f\n\r\t\v\\\"\'", "\65\066", '{ } -- no' }]],
   {"\a\b\f\n\r\t\v\\\"'", "AB", "{ } -- no"})
print("PASS: accepts table literals")

-- Whatever %q writes (the editor's name field) reads back unchanged.
local name = 'q"uo\\te\nline\r\0end} os.exit()'
local got = DefParser.parse(string.format("{ name = %q }", name))
assert(got and got.name == name, "%q round trip")
print("PASS: %q round trip")

-- Every shipped puzzle reads the same as running it.
local PuzzleLoader = require("lua/game/puzzle_loader")
for i = 1, PuzzleLoader.count() do
    local def = PuzzleLoader.load(i)
    local path = PuzzleLoader.path(i)
    local handle = assert(path and io.open(path, "r"), "puzzle file " .. i)
    local text = handle:read("*a")
    handle:close()
    local parsed, err = DefParser.parse(text)
    assert(parsed, path .. ": " .. tostring(err))
    assert(same(parsed, def), path .. " differs")
end
print("PASS: all shipped puzzles")

bad(nil)
bad("")
bad("not valid lua!!!")
bad("returnx {}")
bad("return 1")
bad("os.exit()")
bad("return os.exit()")
bad("{ a = os.exit() }")
bad("{ os.exit() }")
bad("{ a = b }")
bad("{ a = 1 + 1 }")
bad("{ a = ('x'):rep(10) }")
bad("{ a = function() end }")
bad("{ a = [[long]] }")
bad("{} os.exit()")
bad("while true do end return {}")
bad("{ [1] = 2 }")
bad("{ ['a' = 2 }")
bad("{ ['a'] 2 }")
bad("{ a = 1 b = 2 }")
bad("{ a = 1")
bad("{ a = 'x }")
bad("{ a = 'x\ny' }")
bad([[{ a = '\q' }]])
bad([[{ a = '\999' }]])
bad("{ a = 12abc }")
bad("{ a = - }")
bad("--[[ never closed {}")
bad(string.rep("{", 40) .. string.rep("}", 40), "deep nesting")
bad("{}" .. string.rep(" ", 100001), "oversized")
bad("\27LJ\2", "bytecode")
print("PASS: rejects anything else")
