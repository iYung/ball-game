-- test_row_op_delete_resize.lua
-- Tests for:
--   1. Erase tool (palette:is_eraser()) removes any placed op tile on left-click.
--   2. scale_row is placed with tile_rows=4 and can be resized via grow_row/shrink_row.

local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
    return ctx.sm.current
end

-- ── Erase ──────────────────────────────────────────────────────────────────

-- Helper: simulate a left-click at grid cell (cx, cy) in screen coordinates.
local GRID_X, GRID_Y, CELL_SIZE = 95, 20, 63
local function cell_center(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE + CELL_SIZE / 2,
           GRID_Y + (cy - 1) * CELL_SIZE + CELL_SIZE / 2
end

-- Erase removes scale_row
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    assert(scene.grid:get(4, 3) ~= nil, "scale_row was placed")

    scene.palette:select(nil)  -- erase mode (is_eraser() == true)
    local mx, my = cell_center(4, 3)
    scene:mouse_pressed(mx, my, 1)
    assert(scene.grid:get(4, 3) == nil, "erase removes scale_row anchor")
    print("PASS: erase removes scale_row")
end

-- Erase removes swap_rows (click on its ref cell)
do
    local scene = new_scene()
    scene:_place_tile_at(3, 3, { kind = "op", op = "swap_rows" })
    assert(scene.grid:get(3, 3) ~= nil, "swap_rows was placed")

    scene.palette:select(nil)
    local mx, my = cell_center(3, 4)  -- second row (ref cell)
    scene:mouse_pressed(mx, my, 1)
    assert(scene.grid:get(3, 3) == nil, "erase removes swap_rows via ref cell")
    assert(scene.grid:get(3, 4) == nil, "ref cell also gone")
    print("PASS: erase removes swap_rows via ref cell")
end

-- Erase removes add_matrix (previously blocked)
do
    local scene = new_scene()
    scene:_place_tile_at(4, 2, { kind = "op", op = "add_matrix" })
    assert(scene.grid:get(4, 2) ~= nil, "add_matrix was placed")

    scene.palette:select(nil)
    local mx, my = cell_center(4, 2)
    scene:mouse_pressed(mx, my, 1)
    assert(scene.grid:get(4, 2) == nil, "erase removes add_matrix")
    print("PASS: erase removes add_matrix")
end

-- Left-click with an op selected still edits params (erase guard doesn't fire)
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    local tile = scene.grid:get(4, 3)
    local orig_row = tile.params.row

    -- Select scale_row op in palette (not eraser)
    scene.palette:select({ kind = "op", op = "scale_row" })
    assert(not scene.palette:is_eraser(), "palette has selection, not eraser")

    -- Click band 2 (second cell of scale_row tile at y=4)
    local mx, my = cell_center(4, 4)
    scene:mouse_pressed(mx, my, 1)
    local tile_after = scene.grid:get(4, 3)
    assert(tile_after ~= nil, "tile still exists after param click")
    assert(tile_after.params.row == 2, "band 2 selected, got " .. tostring(tile_after.params.row))
    print("PASS: param click still works when palette is not eraser")
end

-- ── scale_row resize ───────────────────────────────────────────────────────

-- scale_row is placed with tile_rows=4
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    local tile = scene.grid:get(4, 3)
    assert(tile ~= nil, "tile placed")
    assert(tile.tile_rows == 4, "scale_row starts with tile_rows=4, got " .. tostring(tile.tile_rows))
    assert(tile.height == 4, "scale_row height=4, got " .. tostring(tile.height))
    print("PASS: scale_row placed with tile_rows=4")
end

-- shrink_row reduces tile_rows
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    scene:_resize_tile(4, 3, "shrink_row")
    local tile = scene.grid:get(4, 3)
    assert(tile.tile_rows == 3, "tile_rows reduced to 3, got " .. tostring(tile.tile_rows))
    assert(tile.height == 3, "height reduced to 3, got " .. tostring(tile.height))
    -- old row 4 ref cell should be gone
    assert(scene.grid:get(4, 6) == nil, "ref cell at row 6 cleared after shrink (tile was at row 3, height 3 → occupies 3,4,5,6 → actually 3,4,5)")
    print("PASS: scale_row shrinks to tile_rows=3")
end

-- grow_row increases tile_rows
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    scene:_resize_tile(4, 3, "shrink_row")  -- now tile_rows=3
    scene:_resize_tile(4, 3, "grow_row")    -- back to 4
    local tile = scene.grid:get(4, 3)
    assert(tile.tile_rows == 4, "tile_rows back to 4, got " .. tostring(tile.tile_rows))
    assert(tile.height == 4, "height back to 4")
    print("PASS: scale_row grows back to tile_rows=4")
end

-- Cannot shrink below 1
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    for _ = 1, 10 do scene:_resize_tile(4, 3, "shrink_row") end
    local tile = scene.grid:get(4, 3)
    assert(tile.tile_rows == 1, "cannot shrink below 1, got " .. tostring(tile.tile_rows))
    print("PASS: scale_row cannot shrink below 1")
end

-- Cannot grow beyond 4
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    for _ = 1, 10 do scene:_resize_tile(4, 3, "grow_row") end
    local tile = scene.grid:get(4, 3)
    assert(tile.tile_rows == 4, "cannot grow beyond 4, got " .. tostring(tile.tile_rows))
    print("PASS: scale_row cannot grow beyond 4")
end

-- shrink_row clamps params.row to new height
do
    local scene = new_scene()
    scene:_place_tile_at(4, 3, { kind = "op", op = "scale_row" })
    local tile = scene.grid:get(4, 3)
    tile.params.row = 4  -- select band 4
    scene:_resize_tile(4, 3, "shrink_row")  -- tile_rows now 3
    tile = scene.grid:get(4, 3)
    assert(tile.params.row <= tile.tile_rows,
        "params.row clamped to tile_rows after shrink, row=" .. tile.params.row .. " rows=" .. tile.tile_rows)
    print("PASS: params.row clamped on shrink")
end

print("ALL TESTS PASSED")
