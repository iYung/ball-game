-- test_row_op_delete_resize.lua
-- Tests for:
--   1. Erase tool (palette:is_eraser()) removes any placed op tile on left-click.
--   2. With an op selected, a left-click on a placed op tile edits it instead.

local S = require("tests/support/shipped")
local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(S.puzzle("identity")) end)
    return ctx.sm.current
end

-- ── Erase ──────────────────────────────────────────────────────────────────

-- Helper: simulate a left-click at grid cell (cx, cy) in screen coordinates.
local GRID_X, GRID_Y, CELL_SIZE = 130, 10, 52
local function cell_center(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE + CELL_SIZE / 2,
           GRID_Y + (cy - 1) * CELL_SIZE + CELL_SIZE / 2
end

-- Erase removes edge_scale (cell_center is the middle third, which otherwise turns the edge)
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "edge_scale" })
    assert(scene.grid:get(4, 3) ~= nil, "edge_scale was placed")

    scene.palette:select(nil)  -- erase mode (is_eraser() == true)
    local mx, my = cell_center(4, 3)
    scene:mouse_pressed(mx, my, 1)
    assert(scene.grid:get(4, 3) == nil, "erase removes edge_scale from the middle third")
    print("PASS: erase removes edge_scale")
end

-- Erase removes scalar_add
do
    local scene = new_scene()
    scene:_place_tile_at(4, 2, { kind = "op", op = "scalar_add" })
    assert(scene.grid:get(4, 2) ~= nil, "scalar_add was placed")

    scene.palette:select(nil)
    local mx, my = cell_center(4, 2)
    scene:mouse_pressed(mx, my, 1)
    assert(scene.grid:get(4, 2) == nil, "erase removes scalar_add")
    print("PASS: erase removes scalar_add")
end

-- Left-click with an op selected still edits params (erase guard doesn't fire)
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "edge_scale" })
    local tile = scene.grid:get(4, 3)
    assert(tile.params.edge == "top", "starts on the top edge")

    -- Select an op in the palette (not eraser)
    scene.palette:select({ kind = "op", op = "edge_scale" })
    assert(not scene.palette:is_eraser(), "palette has selection, not eraser")

    -- Middle third turns the edge clockwise; the right third raises k
    local mx, my = cell_center(4, 3)
    scene:mouse_pressed(mx, my, 1)
    scene:mouse_pressed(mx + CELL_SIZE / 3, my, 1)
    local tile_after = scene.grid:get(4, 3)
    assert(tile_after == tile, "tile still exists after param click")
    assert(tile_after.params.edge == "right", "edge turned, got " .. tostring(tile_after.params.edge))
    assert(tile_after.params.scalar == 3, "k raised, got " .. tostring(tile_after.params.scalar))
    print("PASS: param click still works when palette is not eraser")
end

-- Right-click on any source cell (anchor or not) leaves the locked source in place.
do
    local scene = new_scene()
    local src = scene.puzzle.source
    local anchor = scene.grid:get(src.x, src.y)
    local ax, ay = scene.grid:get_anchor(src.x, src.y)
    assert(ax == src.x and ay == src.y, "the source anchor resolves to itself")
    local mx, my = cell_center(src.x + 1, src.y + 1)
    scene:mouse_pressed(mx, my, 2)
    assert(anchor.kind == "source" and scene.grid:get(src.x, src.y) == anchor, "source anchor kept")
    assert(scene.grid:get(src.x + 1, src.y + 1) == anchor, "source ref cell kept")
    print("PASS: right-click cannot erase the source")
end

print("ALL TESTS PASSED")
