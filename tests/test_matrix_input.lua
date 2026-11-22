-- test_matrix_input.lua
-- Covers four previously-uncovered regions in matrix_scene.lua:
--   1. Lines 2155-2158  key_pressed("r") and key_pressed("backspace")
--   2. Line  2167       text_input(_)   empty stub
--   3. Lines 1840-1850  mouse_moved with active _drag_tile
--   4. Lines  448-461   _clear_drag restore-to-origin path

local runner = require("lua/headless/runner")

-- Layout constants (must match matrix_scene.lua)
local GRID_X    = 95
local GRID_Y    = 20
local CELL_SIZE = 63

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
    return ctx.sm.current
end

local function cell_center(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE + CELL_SIZE / 2,
           GRID_Y + (cy - 1) * CELL_SIZE + CELL_SIZE / 2
end

-- ── 1. key_pressed("r") ────────────────────────────────────────────────────

do
    local scene = new_scene()
    -- Initially no status and not running
    assert(scene.status == nil, "status starts nil")
    assert(not scene.running, "running starts false")

    -- Press "r" — _cmd_enabled("run") is true when not running.
    -- Either starts a run or sets status="no_pusher" (no pusher placed yet).
    scene:key_pressed("r")
    local ran = scene.running or scene.status ~= nil
    assert(ran, "key_pressed('r') should start run or set status, got running="
        .. tostring(scene.running) .. " status=" .. tostring(scene.status))
    print("PASS: key_pressed('r') activates run command")
end

-- ── 2. key_pressed("backspace") ────────────────────────────────────────────

do
    local scene = new_scene()
    -- Trigger run so that reset becomes enabled.
    scene:key_pressed("r")
    assert(scene.status ~= nil or scene.running,
        "run step: scene should have status or be running")

    -- Press backspace → _cmd_activate("reset") → do_reset() clears status.
    scene:key_pressed("backspace")
    assert(scene.status == nil, "backspace resets status to nil, got " .. tostring(scene.status))
    assert(not scene.running, "backspace stops running, got " .. tostring(scene.running))
    print("PASS: key_pressed('backspace') resets the scene")
end

-- ── 3. text_input(_) ───────────────────────────────────────────────────────

do
    local scene = new_scene()
    -- text_input is a no-op stub; just confirm it doesn't error
    scene:text_input("a")
    scene:text_input("")
    scene:text_input("\n")
    print("PASS: text_input stub accepts any input without error")
end

-- ── 4a. mouse_moved with drag tile inside grid ─────────────────────────────

do
    local scene = new_scene()
    scene._drag_tile = { kind = "pusher", id = 1, width = 1, height = 1 }

    -- Coordinates that land inside the grid panel (cell 3,3).
    local mx, my = cell_center(3, 3)
    scene:mouse_moved(mx, my)
    assert(scene._drag_ghost ~= nil,
        "mouse_moved inside grid should set _drag_ghost, got nil")
    assert(scene._drag_ghost.cx == 3 and scene._drag_ghost.cy == 3,
        "drag ghost at correct cell, got cx=" .. tostring(scene._drag_ghost.cx)
        .. " cy=" .. tostring(scene._drag_ghost.cy))
    print("PASS: mouse_moved inside grid sets _drag_ghost")
end

-- ── 4b. mouse_moved with drag tile outside grid panel ──────────────────────

do
    local scene = new_scene()
    scene._drag_tile  = { kind = "pusher", id = 1, width = 1, height = 1 }
    scene._drag_ghost = { cx = 3, cy = 3 }  -- pre-set so we can verify it clears

    -- Coordinates well outside the grid panel (top-left corner).
    scene:mouse_moved(0, 0)
    assert(scene._drag_ghost == nil,
        "mouse_moved outside grid should clear _drag_ghost")
    print("PASS: mouse_moved outside grid clears _drag_ghost")
end

-- ── 4c. mouse_moved with no drag tile (early return) ───────────────────────

do
    local scene = new_scene()
    scene._drag_tile = nil
    -- Should return immediately without error.
    local mx, my = cell_center(3, 3)
    scene:mouse_moved(mx, my)
    assert(scene._drag_ghost == nil, "no drag tile → _drag_ghost stays nil")
    print("PASS: mouse_moved with no drag tile is a no-op")
end

-- ── 5. _clear_drag restore-to-origin path ──────────────────────────────────

do
    local scene = new_scene()
    local tile  = { kind = "pusher", id = 1, width = 1, height = 1 }
    local ox, oy = 3, 2

    -- Simulate a mid-drag state: tile lifted from (ox, oy).
    scene._drag_tile   = tile
    scene._drag_origin = { x = ox, y = oy }
    scene._drag_ghost  = { cx = ox, cy = oy }

    -- Ensure the grid cell is currently empty (the tile was "lifted").
    scene.grid:set(ox, oy, nil)

    scene:_clear_drag()

    -- After clear, the tile should be restored to its origin cell.
    local restored = scene.grid:get(ox, oy)
    assert(restored == tile,
        "_clear_drag should restore tile to origin cell, got " .. tostring(restored))
    -- Internal drag state must be cleared.
    assert(scene._drag_tile   == nil, "_drag_tile cleared")
    assert(scene._drag_origin == nil, "_drag_origin cleared")
    assert(scene._drag_ghost  == nil, "_drag_ghost cleared")
    print("PASS: _clear_drag restores tile to origin and clears drag state")
end

print("ALL TESTS PASSED")
