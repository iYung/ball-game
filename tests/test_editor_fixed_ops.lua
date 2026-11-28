-- The editor keeps fixed_ops and an empty ops list through Paste, Copy and Test.
require("lua/headless/stubs")
local EditorScene  = require("lua/game/scenes/editor_scene")
local DefParser    = require("lua/game/def_parser")
local PuzzleLoader = require("lua/game/puzzle_loader")
local UI           = require("lua/core/ui")

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function new_editor()
    local sm = {}
    function sm:switch(scene) self.current = scene end
    local editor = EditorScene.new(sm)
    editor:on_enter()
    return editor, sm
end

local function click(scene, id)
    local e = UI.find(scene:ui_elements(), id)
    assert(e, "no element " .. id)
    local x, y = UI.centre(e.rect)
    scene:mouse_pressed(x, y, 1)
end

local function paste(editor, text)
    love.system.setClipboardText(text)
    click(editor, "editor:paste")
end

local function copy(editor)
    love.system.setClipboardText("")
    click(editor, "editor:copy")
    local text = love.system.getClipboardText()
    local def, err = DefParser.parse(text)
    assert(def, "copied text does not parse: " .. tostring(err) .. "\n" .. text)
    return def, text
end

-- The matrix scene that Test opens, entered so that its palette exists.
local function test_scene(editor, sm)
    click(editor, "editor:test")
    local scene = sm.current
    assert(scene and scene._custom_puzzle, "Test did not open the matrix scene")
    scene:on_enter()
    return scene
end

local function definition(extra)
    return 'return { name="Pasted", grid_w=10, grid_h=10, source={x=2,y=2}, sink={x=6,y=2},'
        .. ' input={rows=2,cols=2,values={{1,0},{0,1}}},'
        .. ' target={rows=2,cols=2,values={{1,0},{0,1}}}, ' .. (extra or "") .. ' }'
end

local function index_of(id)
    for n = 1, PuzzleLoader.count() do
        if PuzzleLoader.id(n) == id then return n end
    end
    error("no shipped puzzle with id " .. id)
end

do
    local editor = new_editor()
    local def = copy(editor)
    assert(def.ops == nil and def.fixed_ops == nil, "a new editor has neither ops nor fixed_ops")
    print("PASS: new editor omits ops and fixed_ops")
end

for _, case in ipairs({ { id = "add_only", ops = {} }, { id = "top_only", ops = { "flip_v" } } }) do
    local id = case.id
    local path = PuzzleLoader.path(index_of(id))
    local file = assert(io.open(path, "r"))   -- the headless stubs cannot read files
    local source = file:read("*a")
    file:close()
    local shipped = assert(DefParser.parse(source))
    assert(same(shipped.ops, case.ops), id .. " does not ship the expected ops list")

    local editor, sm = new_editor()
    paste(editor, source)
    assert(editor._paste_error == nil, id .. ": " .. tostring(editor._paste_error))
    local def, text = copy(editor)
    assert(same(def.ops, shipped.ops), id .. " ops changed:\n" .. text)
    assert(same(def.fixed_ops, shipped.fixed_ops), id .. " fixed_ops changed:\n" .. text)

    local again = new_editor()
    paste(again, text)
    local _, text2 = copy(again)
    assert(text2 == text, id .. " changes on a second round trip:\n" .. text2)

    local scene = test_scene(editor, sm)
    assert(same(scene._custom_puzzle.ops, shipped.ops), id .. " ops not passed to Test")
    assert(same(scene._custom_puzzle.fixed_ops, shipped.fixed_ops), id .. " fixed_ops not passed to Test")
    local els = scene:ui_elements()
    assert(not UI.find(els, "palette:transpose"), id .. " offers an unlisted op in Test")
    for _, entry in ipairs(shipped.fixed_ops or {}) do
        local op = type(entry) == "table" and entry.op or entry
        assert(UI.find(els, "palette:fixed:" .. op), id .. " has no fixed button for " .. op)
    end
    print("PASS: " .. id .. " keeps ops and fixed_ops")
end

do
    local editor, sm = new_editor()
    paste(editor, definition([[fixed_ops = {
        "flip_h",
        "scalar_add",
        { op = "transpose" },
        { op = "flip_v", params = { scalar = 3 } },
        { op = "scalar_mul" },
        { op = "scalar_sub", params = {} },
        { op = "edge_add", params = { edge = "left", scalar = 4, junk = 1 } },
        { op = "edge_scale", params = { edge = "bottom" } },
    }]]))
    assert(editor._paste_error == nil, tostring(editor._paste_error))
    local expected = {
        "flip_h",
        "scalar_add",
        { op = "transpose" },
        { op = "flip_v" },
        { op = "scalar_mul" },
        { op = "scalar_sub", params = { scalar = 1 } },
        { op = "edge_add", params = { edge = "left", scalar = 4 } },
        { op = "edge_scale", params = { edge = "bottom", scalar = 2 } },
    }
    local def, text = copy(editor)
    assert(same(def.fixed_ops, expected), "fixed_ops not normalised:\n" .. text)
    assert(def.ops == nil, "no ops list was pasted")
    assert(text:find('{ op = "edge_add", params = { edge = "left", scalar = 4 } }', 1, true),
        "param keys are sorted and strings quoted:\n" .. text)

    local scene = test_scene(editor, sm)
    local passed = scene._custom_puzzle.fixed_ops
    assert(same(passed, expected), "Test gets the same list")
    passed[7].params.scalar = 9
    assert(same(copy(editor).fixed_ops, expected), "Test gets a copy, not the editor's list")
    print("PASS: string and table entries")
end

for _, case in ipairs({
    { 'fixed_ops = { "abs" }',                  "Unsupported op: abs" },
    { 'fixed_ops = { "flip_v", { op="abs" } }', "Unsupported op: abs" },
    { 'fixed_ops = { {} }',                     "Unsupported op: nil" },
    { 'fixed_ops = { 7 }',                      "Unsupported op: 7" },
    { 'fixed_ops = { { op="scalar_mul", params={scalar=10} } }', "Invalid scalar for scalar_mul: 10" },
    { 'fixed_ops = { { op="edge_add", params={edge="middle"} } }', "Invalid edge: middle" },
    { 'fixed_ops = { { op="scalar_add", params=3 } }', "Invalid params for scalar_add" },
    { 'fixed_ops = "flip_v"',                   "Invalid fixed_ops" },
    { 'fixed_ops = false',                      "Invalid fixed_ops" },
}) do
    local editor = new_editor()
    paste(editor, definition('ops = {}, fixed_ops = { "flip_h" }'))
    local _, before = copy(editor)
    paste(editor, (definition(case[1]):gsub("Pasted", "Rejected")))
    assert(editor._paste_error == case[2],
        case[1] .. ": expected '" .. case[2] .. "', got " .. tostring(editor._paste_error))
    local _, after = copy(editor)
    assert(after == before, case[1] .. " changed the editor:\n" .. after)
end
print("PASS: bad fixed_ops rejected")

do
    local editor, sm = new_editor()
    paste(editor, definition('ops = {}, fixed_ops = { "flip_h" }'))
    paste(editor, definition())
    local def = copy(editor)
    assert(def.ops == nil and def.fixed_ops == nil, "a later paste clears both")
    local scene = test_scene(editor, sm)
    assert(scene._custom_puzzle.ops == nil and scene._custom_puzzle.fixed_ops == nil,
        "Test gets neither after a later paste")

    paste(editor, definition('fixed_ops = {}'))
    assert(copy(editor).fixed_ops == nil, "an empty fixed_ops list is omitted")
    print("PASS: later paste clears both")
end

do
    local editor, sm = new_editor()
    paste(editor, definition("ops = {}"))
    assert(same(copy(editor).ops, {}), "ops = {} is kept")

    click(editor, "editor:allow:transpose")
    assert(same(copy(editor).ops, { "transpose" }), "a toggle replaces the empty list")
    assert(same(test_scene(editor, sm)._custom_puzzle.ops, { "transpose" }), "Test agrees")

    click(editor, "editor:allow:transpose")
    assert(copy(editor).ops == nil, "toggling back off offers every op")
    assert(test_scene(editor, sm)._custom_puzzle.ops == nil, "Test agrees")
    print("PASS: allow toggle after ops = {}")
end
