-- Placing and turning two-cell tiles in the puzzle scene: palette membership and
-- layout, tool facing, placement, rotation, Mv, previews and the T key.

local runner      = require("lua/headless/runner")
local Stubs       = require("lua/headless/stubs")
local UI          = require("lua/core/ui")
local UIRunner    = require("lua/headless/ui_runner")
local Ops         = require("lua/game/ops")
local Timeline    = require("lua/game/timeline")
local MatrixScene = require("lua/game/scenes/matrix_scene")

local function make_def(o)
    return {
        name = "edit", grid_w = o.size or 10, grid_h = o.size or 10,
        source = { x = 1, y = 9 }, input = { rows = 1, cols = 1, values = { { 1 } } },
        sink = { x = 10, y = 10 }, target = { rows = 1, cols = 1, values = { { 1 } } },
        ops = o.ops, fixed_ops = o.fixed_ops, locked = o.locked,
    }
end

local BOTH = { "matrix_add", "matrix_mul", "transpose" }

local function new_scene(o)
    local def = make_def(o or { ops = BOTH })
    local ctx = runner.setup(function(_, sm) return MatrixScene.new_from_def(def, sm) end)
    return ctx.sm.current
end

local function element(scene, id)
    return assert(UI.find(scene:ui_elements(), id), "element " .. id .. " missing")
end
local function centre(scene, id) return UI.centre(element(scene, id).rect) end
local function cell(x, y) return "cell:" .. x .. "," .. y end

local function move(scene, id) scene:mouse_moved(centre(scene, id)) end
local function down(scene, id, b)
    local x, y = centre(scene, id)
    scene:mouse_moved(x, y)
    scene:mouse_pressed(x, y, b or 1)
end
local function up(scene, id, b)
    local x, y = centre(scene, id)
    scene:mouse_moved(x, y)
    scene:mouse_released(x, y, b or 1)
end
local function click(scene, id, b) down(scene, id, b); up(scene, id, b) end

local function label(scene, id) return element(scene, id).label end

local function expect(scene, x, y, op, facing)
    local t = scene:ui_tile(x, y)
    if op == nil then
        assert(t == nil, "expected empty at " .. x .. "," .. y .. ", got " .. tostring(t and t.kind))
    else
        assert(t and t.op == op and t.facing == facing, "at " .. x .. "," .. y .. ": "
            .. tostring(t and t.op) .. " " .. tostring(t and t.facing))
    end
end

-- Every rectangle fill and text of one draw.
local function drawn(scene)
    local fills, color = {}, nil
    local set, rect = love.graphics.setColor, love.graphics.rectangle
    love.graphics.setColor = function(r, g, b) color = type(r) == "table" and r or { r, g, b } end
    love.graphics.rectangle = function(mode, x, y)
        if mode == "fill" then fills[#fills + 1] = { x = x, y = y, color = color } end
    end
    Stubs.clear_text()
    local ok, err = pcall(scene.draw, scene)
    love.graphics.setColor, love.graphics.rectangle = set, rect
    assert(ok, err)
    local seen = {}
    for _, t in ipairs(Stubs.drawn_text()) do seen[t] = (seen[t] or 0) + 1 end
    return seen, fills
end

-- "green", "red" or nil: the drag preview fill on a cell.
local function preview_at(scene, x, y)
    local _, fills = drawn(scene)
    local r = element(scene, cell(x, y)).rect
    for _, f in ipairs(fills) do
        if f.x == r.x and f.y == r.y and f.color[3] == 0.14 then
            if f.color[1] == 0.14 and f.color[2] == 0.35 then return "green" end
            if f.color[1] == 0.35 and f.color[2] == 0.14 then return "red" end
        end
    end
    return nil
end

-- ── Palette ──────────────────────────────────────────────────────────────────
do
    local all = {}
    for _, op in ipairs(Ops.ORDER) do all[#all + 1] = op end
    for _, op in ipairs(Ops.MATRIX_ORDER) do all[#all + 1] = op end
    local scene = new_scene({ ops = all })
    local els = scene:ui_elements()
    assert(UIRunner.check_invariants(els) == nil, "invariants")
    assert(not UI.find(els, "palette:scroll_up") and not UI.find(els, "palette:scroll_down"), "no arrows")
    for _, op in ipairs(all) do assert(UI.find(els, "palette:" .. op), op .. " offered") end
    local erase = element(scene, "palette:erase").rect
    assert(erase.y + erase.h == 510, "ends at 510, got " .. (erase.y + erase.h))
    local flip, add = element(scene, "palette:flip_v").rect, element(scene, "palette:matrix_add").rect
    assert(add.y == element(scene, "palette:flip_h").rect.y + 56, "no separator before M+")
    assert(flip.y == element(scene, "palette:flip_h").rect.y and add.x == 8, "M+ starts the third row")
    assert(label(scene, "palette:matrix_add") == "M+>" and label(scene, "palette:matrix_mul") == "Mx>",
        "arrow labels")
    assert(drawn(scene)["M+>"], "label drawn")

    local classic = new_scene({})
    local ids = 0
    for _, e in ipairs(classic:ui_elements()) do
        if e.id:sub(1, 8) == "palette:" then ids = ids + 1 end
    end
    assert(ids == 10 + 3, "no ops list: the ten classic ops, got " .. ids)
    assert(not UI.find(classic:ui_elements(), "palette:matrix_add"), "no matrix op without a list")

    local fixed = new_scene({ ops = {}, fixed_ops = { { op = "matrix_mul", params = { facing = "bottom" } } } })
    assert(label(fixed, "palette:fixed:matrix_mul") == "Mxv!", "fixed label")
    assert(not UI.find(fixed:ui_elements(), "palette:matrix_mul"), "fixed only")
    print("PASS: two-cell palette entries and layout")
end

-- Switching puzzles drops a matrix tool the new one does not offer; facing resets.
do
    local scene = new_scene()
    local function switch(o)
        scene._custom_puzzle = make_def(o)
        scene:load_puzzle()
        return scene.palette:selected()
    end
    click(scene, "palette:matrix_add")
    click(scene, "palette:matrix_add")
    assert(label(scene, "palette:matrix_add") == "M+v", "turned")
    local sel = switch({ ops = BOTH })
    assert(sel and sel.op == "matrix_add", "still offered: kept")
    assert(label(scene, "palette:matrix_add") == "M+>", "facing reset on load")
    assert(switch({}) == nil, "no ops list: dropped")
    switch({ ops = BOTH })
    click(scene, "palette:matrix_mul")
    assert(switch({ ops = { "transpose" } }) == nil, "not listed: dropped")
    switch({ ops = BOTH })
    click(scene, "palette:matrix_mul")
    assert(switch({ ops = {}, fixed_ops = { "matrix_mul" } }) == nil, "editable tool, fixed offer: dropped")
    click(scene, "palette:fixed:matrix_mul")
    sel = switch({ ops = {}, fixed_ops = { { op = "matrix_mul", params = { facing = "top" } } } })
    assert(sel and sel.fixed and sel.params.facing == "top", "fixed tool takes the new preset")
    assert(switch({ ops = BOTH }) == nil, "fixed tool, editable offer: dropped")
    print("PASS: tool selection across puzzles")
end

-- ── Turning the tool ─────────────────────────────────────────────────────────
do
    local scene = new_scene({ ops = BOTH, fixed_ops = { "matrix_add" } })
    local id = "palette:matrix_add"
    click(scene, id)
    assert(label(scene, id) == "M+>", "first click only selects")
    down(scene, id)
    assert(label(scene, id) == "M+>", "not on press when idle")
    up(scene, id)
    assert(label(scene, id) == "M+v", "turns on release")
    click(scene, id, 2)
    assert(label(scene, id) == "M+v", "right-click never turns")
    down(scene, id)
    move(scene, cell(5, 5))
    up(scene, id)
    assert(label(scene, id) == "M+v", "left the button: no turn")
    -- A release elsewhere with no move event in between does not turn either.
    down(scene, id)
    scene:mouse_released(0, 0, 1)
    assert(label(scene, id) == "M+v", "released off the button")
    down(scene, id)
    scene:key_pressed("t")
    assert(label(scene, id) == "M+<", "T during the hold turns")
    up(scene, id)
    assert(label(scene, id) == "M+<", "and the release does not turn again")
    click(scene, "palette:fixed:matrix_add")
    click(scene, "palette:fixed:matrix_add")
    scene:key_pressed("t")
    assert(label(scene, "palette:fixed:matrix_add") == "M+>!", "fixed never turns")
    assert(label(scene, id) == "M+<", "other tool untouched")

    -- While running there is no drag: a second click turns on press.
    scene.running = true
    down(scene, id)
    assert(label(scene, id) == "M+<", "first click selects")
    up(scene, id)
    down(scene, id)
    assert(label(scene, id) == "M+^", "turns on press")
    up(scene, id)
    assert(label(scene, id) == "M+^", "once")
    click(scene, id, 2)
    assert(label(scene, id) == "M+^", "right-click never turns while running")
    scene:key_pressed("t")
    assert(label(scene, id) == "M+>", "T during a run")
    print("PASS: turning the tool")
end

-- T is ignored under the settings overlay, and while other things are dragged.
do
    local scene = new_scene()
    click(scene, "palette:matrix_add")
    scene:key_pressed("escape")
    scene:key_pressed("t")
    scene:key_pressed("escape")
    assert(label(scene, "palette:matrix_add") == "M+>", "ignored in settings")

    click(scene, cell(5, 5))
    for _, id in ipairs({ "chip:up", "palette:transpose" }) do
        down(scene, id)                                    -- hold the other thing
        scene.palette:select({ kind = "op", op = "matrix_add" })
        move(scene, cell(5, 5))
        scene:key_pressed("t")
        expect(scene, 5, 5, "matrix_add", "right")
        assert(label(scene, "palette:matrix_add") == "M+>", id .. ": nothing turned")
        scene:mouse_released(0, 0, 1)
    end
    -- No pointer yet: T goes to the selected tool.
    local fresh = new_scene()
    fresh.palette:select({ kind = "op", op = "matrix_mul" })
    fresh:key_pressed("t")
    assert(label(fresh, "palette:matrix_mul") == "Mxv", "tool turned without a pointer")
    print("PASS: T priority and ignored cases")
end

-- ── Placement, rotation, erasing ─────────────────────────────────────────────
do
    local scene = new_scene({ ops = BOTH, locked = { { kind = "op", op = "matrix_mul", x = 8, y = 2 } } })
    click(scene, "palette:matrix_add")
    click(scene, cell(10, 1))
    expect(scene, 10, 1, nil)                         -- partner off the grid
    scene:_place_tile_at(4, 5, { kind = "pusher" })
    click(scene, cell(3, 5))
    expect(scene, 3, 5, nil)                          -- partner occupied
    click(scene, cell(4, 5))
    assert(scene:ui_tile(4, 5).kind == "pusher", "nothing overwritten")
    click(scene, cell(5, 5))
    expect(scene, 5, 5, "matrix_add", "right")
    expect(scene, 6, 5, "matrix_add", "right")
    click(scene, "palette:matrix_mul")
    click(scene, cell(6, 5))                          -- any tool turns it
    expect(scene, 5, 5, "matrix_add", "bottom")
    expect(scene, 6, 5, nil)
    click(scene, "palette:pusher")
    click(scene, cell(5, 6))                          -- left is the pusher: skipped
    expect(scene, 5, 4, "matrix_add", "top")
    click(scene, "palette:drag")
    scene.running = true
    click(scene, cell(5, 5))                          -- Mv never turns
    expect(scene, 5, 5, "matrix_add", "top")
    click(scene, "palette:transpose")
    click(scene, cell(5, 4))                          -- grid edits work during a run
    expect(scene, 6, 5, "matrix_add", "right")
    move(scene, cell(5, 5))
    scene:key_pressed("t")                            -- T over the tile
    expect(scene, 5, 6, "matrix_add", "bottom")
    scene.running = false
    assert(scene:_count_pieces() == 2, "one piece per tile")

    click(scene, "palette:erase")
    click(scene, cell(5, 6))
    expect(scene, 5, 5, nil)
    expect(scene, 5, 6, nil)
    click(scene, "palette:matrix_add")
    click(scene, cell(5, 5))
    click(scene, cell(6, 5), 2)
    expect(scene, 5, 5, nil)

    -- Locked: no turn, no erase, no lift; T over it falls through to the tool.
    click(scene, "palette:transpose")
    click(scene, cell(9, 2))
    click(scene, cell(9, 2), 2)
    click(scene, "palette:erase")
    click(scene, cell(8, 2))
    click(scene, "palette:drag")
    down(scene, cell(9, 2))
    assert(scene._drag_tile == nil, "locked not lifted")
    up(scene, cell(1, 1))
    expect(scene, 8, 2, "matrix_mul", "right")
    expect(scene, 9, 2, "matrix_mul", "right")
    click(scene, "palette:matrix_add")
    move(scene, cell(9, 2))
    scene:key_pressed("t")
    expect(scene, 8, 2, "matrix_mul", "right")
    assert(label(scene, "palette:matrix_add") == "M+v", "fell through to the tool")

    -- T over a classic tile or an empty cell also goes to the tool.
    scene:_place_tile_at(2, 2, { kind = "op", op = "edge_add" })
    move(scene, cell(2, 2))
    scene:key_pressed("t")
    assert(scene:ui_tile(2, 2).edge == "top", "classic tile untouched")
    move(scene, cell(3, 3))
    scene:key_pressed("t")
    assert(label(scene, "palette:matrix_add") == "M+^", "tool turned")

    -- A boxed-in tile cannot turn, and the tool is left alone.
    scene:_place_tile_at(1, 1, { kind = "op", op = "matrix_add", params = { facing = "right" } })
    scene:_place_tile_at(1, 2, { kind = "pusher" })
    move(scene, cell(1, 1))
    scene:key_pressed("t")
    expect(scene, 2, 1, "matrix_add", "right")
    assert(label(scene, "palette:matrix_add") == "M+^", "stops at the tile")
    print("PASS: placing, turning and erasing")
end

-- ── Mv ───────────────────────────────────────────────────────────────────────
do
    local scene = new_scene({ ops = BOTH, fixed_ops = { { op = "matrix_mul", params = { facing = "bottom" } } } })
    click(scene, "palette:matrix_add")
    click(scene, cell(3, 3))
    click(scene, "palette:drag")

    down(scene, cell(4, 3))                            -- by the right operand
    assert(scene._drag_origin.x == 3 and scene._drag_grab == "R", "anchor and grab")
    expect(scene, 3, 3, nil)
    move(scene, cell(7, 6))
    assert(preview_at(scene, 6, 6) == "green" and preview_at(scene, 7, 6) == "green", "valid preview")
    local seen = drawn(scene)
    assert(seen["L M+"] and seen["R M+"], "both operands previewed")
    scene:key_pressed("t")                             -- turns freely, R stays under the cursor
    assert(preview_at(scene, 7, 5) == "green" and preview_at(scene, 7, 6) == "green", "turned preview")
    up(scene, cell(7, 6))
    expect(scene, 7, 5, "matrix_add", "bottom")
    expect(scene, 7, 6, "matrix_add", "bottom")
    assert(scene._drag_tile == nil and scene._drag_grab == nil, "drag cleared")

    down(scene, cell(7, 6))
    move(scene, cell(5, 1))                            -- anchor would be above the grid
    assert(preview_at(scene, 5, 1) == "red", "invalid preview")
    up(scene, cell(5, 1))
    expect(scene, 7, 5, "matrix_add", "bottom")

    down(scene, cell(7, 5))
    scene:key_pressed("t")
    move(scene, cell(2, 9))                            -- facing left onto the source: invalid
    assert(preview_at(scene, 2, 9) == "red" and preview_at(scene, 1, 9) == "red", "occupied preview")
    up(scene, cell(2, 9))
    expect(scene, 7, 6, "matrix_add", "bottom")

    down(scene, cell(7, 5))
    scene:key_pressed("t")
    scene:mouse_released(0, 0, 1)                      -- no move event: ghost still at the origin
    expect(scene, 6, 5, "matrix_add", "left")
    down(scene, cell(6, 5))
    scene:key_pressed("t")
    scene:mouse_moved(0, 0)
    scene:mouse_released(0, 0, 1)                      -- off the grid
    expect(scene, 6, 5, "matrix_add", "left")
    expect(scene, 7, 5, "matrix_add", "left")

    down(scene, cell(6, 5))
    scene:key_pressed("t")
    down(scene, cell(2, 2), 2)                         -- right-click cancels
    expect(scene, 6, 5, "matrix_add", "left")
    up(scene, cell(2, 2))
    expect(scene, 2, 2, nil)

    -- A nil grab means the anchor.
    down(scene, cell(7, 5))
    scene._drag_grab = nil
    up(scene, cell(4, 4))
    expect(scene, 3, 4, "matrix_add", "left")

    -- Reset while holding a tile puts it back.
    scene.status = "fail"
    down(scene, cell(4, 4))
    scene:key_pressed("t")
    scene:key_pressed("backspace")
    assert(scene._drag_tile == nil, "drag ended")
    expect(scene, 3, 4, "matrix_add", "left")
    up(scene, cell(8, 8))

    -- Fixed: moves and erases, never turns.
    click(scene, "palette:fixed:matrix_mul")
    click(scene, cell(8, 8))
    click(scene, cell(8, 9))
    expect(scene, 8, 8, "matrix_mul", "bottom")
    move(scene, cell(8, 8))
    scene:key_pressed("t")
    expect(scene, 8, 8, "matrix_mul", "bottom")
    click(scene, "palette:drag")
    down(scene, cell(8, 9))
    scene:key_pressed("t")
    up(scene, cell(5, 8))
    expect(scene, 5, 7, "matrix_mul", "bottom")
    click(scene, cell(5, 8), 2)
    expect(scene, 5, 7, nil)

    -- T does nothing to a held classic tile or pusher.
    click(scene, "palette:transpose")
    click(scene, cell(9, 1))
    click(scene, "palette:drag")
    down(scene, cell(9, 1))
    move(scene, cell(9, 2))
    scene:key_pressed("t")
    assert(drawn(scene)["T"], "classic ghost")
    up(scene, cell(9, 2))
    assert(scene:ui_tile(9, 2).op == "transpose", "moved")
    print("PASS: Mv with two-cell tiles")
end

-- ── Palette drag preview ─────────────────────────────────────────────────────
do
    local scene = new_scene({ ops = BOTH, fixed_ops = { { op = "matrix_mul", params = { facing = "left" } } } })
    down(scene, "palette:matrix_add")
    assert(preview_at(scene, 5, 5) == nil, "nothing before moving")
    move(scene, cell(5, 5))
    assert(preview_at(scene, 5, 5) == "green" and preview_at(scene, 6, 5) == "green", "valid")
    scene:key_pressed("t")
    local seen = drawn(scene)
    assert(seen["M+v"] == 2, "button and floating ghost show the new facing: " .. tostring(seen["M+v"]))
    assert(preview_at(scene, 5, 6) == "green", "preview follows")
    move(scene, cell(5, 10))
    assert(preview_at(scene, 5, 10) == "red", "partner off the grid")
    scene:mouse_moved(0, 0)
    assert(not drawn(scene)["L M+"], "no preview off the grid")
    move(scene, cell(5, 5))
    scene.running = true
    assert(preview_at(scene, 5, 5) == nil, "no preview during a run")
    scene.running = false
    up(scene, cell(5, 5))
    expect(scene, 5, 6, "matrix_add", "bottom")

    down(scene, "palette:fixed:matrix_mul")
    move(scene, cell(5, 5))
    assert(preview_at(scene, 5, 5) == "red" and preview_at(scene, 4, 5) == "red", "occupied")
    move(scene, cell(8, 2))
    assert(preview_at(scene, 7, 2) == "green", "fixed preset facing previewed")
    up(scene, cell(8, 2))
    expect(scene, 7, 2, "matrix_mul", "left")

    down(scene, "palette:transpose")
    move(scene, cell(2, 2))
    assert(preview_at(scene, 2, 2) == nil, "classic palette drags have no board preview")
    up(scene, cell(2, 2))
    print("PASS: palette drag preview")
end

-- A player-placed tile is used by the run, and turning is allowed during it.
do
    local scene = new_scene()
    click(scene, "palette:matrix_add")
    click(scene, cell(5, 5))
    scene:_place_tile_at(1, 1, { kind = "pusher" })
    Timeline.set(scene.timeline, 1, 1, 1, "right")
    scene:start_run()
    click(scene, cell(5, 5))
    expect(scene, 5, 6, "matrix_add", "bottom")
    scene:do_reset()
    expect(scene, 5, 6, "matrix_add", "bottom")
    print("PASS: turning during a run")
end
