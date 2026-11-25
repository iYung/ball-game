-- Editor pusher ids: the 8 limit, reuse after erase, import assignment and export.
local runner      = require("lua/headless/runner")
local UI          = require("lua/core/ui")
local EditorScene = require("lua/game/scenes/editor_scene")

local function new_editor()
    local ctx = runner.setup(function(_, sm) return EditorScene.new(sm) end)
    runner.tick(ctx.input, ctx.sm, 1)
    return ctx.sm.current
end

local function click(scene, id, button)
    local e = UI.find(scene:ui_elements(), id)
    assert(e, "no element " .. id)
    local x, y = UI.centre(e.rect)
    scene:mouse_pressed(x, y, button or 1)
end

local function id_at(scene, x, y)
    local tile = scene._grid:get(x, y)
    return tile and tile.id
end

local function pusher_count(def)
    local n = 0
    for _, e in ipairs(def.locked or {}) do
        if e.kind == "pusher" then n = n + 1 end
    end
    return n
end

local function def_with(locked)
    return { locked = locked,
             input  = { rows = 1, cols = 1, values = { {0} } },
             target = { rows = 1, cols = 1, values = { {0} } } }
end

-- Placement: ids 1..8 in order, a ninth is refused
do
    local s = new_editor()
    click(s, "editor:pal:pusher")
    for x = 1, 9 do click(s, "cell:" .. x .. ",5") end
    for x = 1, 8 do assert(id_at(s, x, 5) == x, "pusher " .. x .. " gets id " .. x) end
    assert(s._grid:get(9, 5) == nil, "ninth pusher refused")
    assert(pusher_count(s:_build_def()) == 8, "def holds 8 pushers")
    print("PASS: pusher limit")

    -- erased ids are reused, lowest first
    click(s, "cell:6,5", 2)
    click(s, "cell:2,5", 2)
    click(s, "cell:9,5")
    assert(id_at(s, 9, 5) == 2, "lowest erased id reused")
    click(s, "cell:10,5")
    assert(id_at(s, 10, 5) == 6, "next erased id reused")
    print("PASS: pusher id reuse")
end

-- Export writes the id, in both the def and the clipboard text
do
    local s = new_editor()
    click(s, "editor:pal:pusher")
    click(s, "cell:3,3")
    click(s, "cell:4,3")
    click(s, "cell:3,3", 2)
    local def = s:_build_def()
    assert(def.locked[1].id == 2, "def entry carries id")
    local text = s:_serialize()
    assert(text:find('kind="pusher", x=4, y=3, id=2', 1, true), "serialized id: " .. text)
    assert(load(text)().locked[1].id == 2, "text loads with id")
    local loaded = load(text)()
    assert(loaded.input.values[1][1] == 1 and loaded.target.values[2][2] == 1,
        "matrix values keep their nesting: " .. text)
    print("PASS: pusher id export")
end

-- Import: valid explicit ids are kept and reserved before others are assigned
do
    local s = new_editor()
    s:_load_def(def_with({
        { kind = "pusher", x = 1, y = 3 },             -- missing
        { kind = "pusher", x = 2, y = 3, id = 1 },     -- explicit, listed later
        { kind = "pusher", x = 3, y = 3, id = 5 },
        { kind = "pusher", x = 4, y = 3, id = 5 },     -- duplicate
        { kind = "pusher", x = 5, y = 3, id = 9 },     -- too high
        { kind = "pusher", x = 6, y = 3, id = 0 },     -- too low
        { kind = "pusher", x = 7, y = 3, id = 2.5 },   -- not an integer
        { kind = "pusher", x = 8, y = 3, id = "A" },   -- not a number
        { kind = "pusher", x = 99, y = 3, id = 8 },    -- off grid: reserves nothing
    }))
    local want = { 2, 1, 5, 3, 4, 6, 7, 8 }
    for x, id in ipairs(want) do
        assert(id_at(s, x, 3) == id,
            "x=" .. x .. ": expected id " .. id .. ", got " .. tostring(id_at(s, x, 3)))
    end
    print("PASS: pusher id import")
end

-- Import: pushers beyond the limit are skipped; a later explicit id still wins its letter
do
    local s = new_editor()
    local locked = {}
    for x = 1, 9 do locked[#locked+1] = { kind = "pusher", x = x, y = 4 } end
    locked[#locked+1] = { kind = "pusher", x = 10, y = 4, id = 1 }
    s:_load_def(def_with(locked))
    assert(id_at(s, 10, 4) == 1, "explicit id kept")
    for x = 1, 7 do assert(id_at(s, x, 4) == x + 1, "assigned id at " .. x) end
    assert(s._grid:get(8, 4) == nil and s._grid:get(9, 4) == nil, "extra pushers skipped")
    assert(pusher_count(s:_build_def()) == 8, "still 8 pushers")
    print("PASS: pusher import limit")
end

-- The puzzle scene keeps the ids of a built def
do
    local s = new_editor()
    click(s, "editor:pal:pusher")
    click(s, "cell:5,5")
    click(s, "cell:7,5")
    click(s, "cell:5,5", 2)
    local MatrixScene = require("lua/game/scenes/matrix_scene")
    local def = s:_build_def()
    local ctx = runner.setup(function(_, sm) return MatrixScene.new_from_def(def, sm) end)
    runner.tick(ctx.input, ctx.sm, 1)
    local tile = ctx.sm.current.grid:get(7, 5)
    assert(tile and tile.id == 2, "load_puzzle copies the pusher id")
    print("PASS: pusher id in puzzle scene")
end
