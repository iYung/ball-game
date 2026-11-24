local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
    return ctx.sm.current
end

local function select_drag(scene)
    scene.palette:select({ kind = "drag" })
end

-- Palette: is_drag() reflects drag selection state.
do
    local scene = new_scene()
    assert(not scene.palette:is_drag(), "not in drag mode initially")
    select_drag(scene)
    assert(scene.palette:is_drag(), "is_drag() true after selecting drag")
    scene.palette:select({ kind = "op", op = "transpose" })
    assert(not scene.palette:is_drag(), "is_drag() false after switching away")
    print("PASS: palette is_drag()")
end

-- Lifting a tile into drag state clears the grid cell.
do
    local scene = new_scene()
    scene:_place_tile_at(3, 3, { kind = "op", op = "negate" })
    assert(scene.grid:get(3, 3) ~= nil, "tile placed")
    select_drag(scene)
    scene:mouse_pressed(scene._btn_rects and 0 or 0, 0, 1)  -- just ensure no crash
    -- Directly test via mouse_pressed on the tile cell
    local sx = 130 + (3 - 1) * 52 + 10  -- inside cell (3,3)
    local sy = 10 + (3 - 1) * 52 + 10
    scene:mouse_pressed(sx, sy, 1)
    assert(scene._drag_tile ~= nil, "tile lifted into _drag_tile")
    assert(scene._drag_tile.op == "negate", "correct tile lifted")
    assert(scene._drag_origin.x == 3 and scene._drag_origin.y == 3, "origin stored")
    assert(scene.grid.cells[3][3] == nil, "original cell cleared")
    print("PASS: lifting a tile")
end

-- Dropping onto a valid empty cell places the tile there.
do
    local scene = new_scene()
    scene:_place_tile_at(3, 3, { kind = "op", op = "transpose" })
    select_drag(scene)
    local sx = 130 + (3 - 1) * 52 + 10
    local sy = 10 + (3 - 1) * 52 + 10
    scene:mouse_pressed(sx, sy, 1)
    assert(scene._drag_tile ~= nil, "tile in flight")
    -- Move to cell (5,5)
    scene:mouse_moved(130 + (5 - 1) * 52 + 10, 10 + (5 - 1) * 52 + 10)
    assert(scene._drag_ghost ~= nil, "ghost set after mouse_moved")
    assert(scene._drag_ghost.cx == 5 and scene._drag_ghost.cy == 5, "ghost at (5,5)")
    -- Release
    scene:mouse_released(130 + (5 - 1) * 52 + 10, 10 + (5 - 1) * 52 + 10, 1)
    assert(scene._drag_tile == nil, "drag state cleared after drop")
    assert(scene.grid:get(5, 5) ~= nil, "tile placed at target")
    assert(scene.grid:get(5, 5).op == "transpose", "correct tile at target")
    assert(scene.grid.cells[3][3] == nil, "source cell still empty")
    print("PASS: drop onto valid cell")
end

-- Dropping onto an occupied cell cancels — tile snaps back to origin.
do
    local scene = new_scene()
    scene:_place_tile_at(3, 3, { kind = "op", op = "negate" })
    scene:_place_tile_at(5, 5, { kind = "op", op = "transpose" })
    select_drag(scene)
    local sx = 130 + (3 - 1) * 52 + 10
    local sy = 10 + (3 - 1) * 52 + 10
    scene:mouse_pressed(sx, sy, 1)
    scene:mouse_moved(130 + (5 - 1) * 52 + 10, 10 + (5 - 1) * 52 + 10)
    scene:mouse_released(130 + (5 - 1) * 52 + 10, 10 + (5 - 1) * 52 + 10, 1)
    assert(scene._drag_tile == nil, "drag state cleared after cancel")
    assert(scene.grid:get(3, 3) ~= nil, "negate snapped back to origin")
    assert(scene.grid:get(3, 3).op == "negate", "correct tile at origin")
    assert(scene.grid:get(5, 5).op == "transpose", "obstacle tile untouched")
    print("PASS: drop onto occupied cell cancels")
end

-- Right-click during drag cancels and snaps tile back.
do
    local scene = new_scene()
    scene:_place_tile_at(4, 4, { kind = "op", op = "scalar_mul", params = { scalar = 3 } })
    select_drag(scene)
    local sx = 130 + (4 - 1) * 52 + 10
    local sy = 10 + (4 - 1) * 52 + 10
    scene:mouse_pressed(sx, sy, 1)
    assert(scene._drag_tile ~= nil, "tile lifted")
    scene:mouse_pressed(sx, sy, 2)
    assert(scene._drag_tile == nil, "right-click cancelled drag")
    assert(scene.grid:get(4, 4) ~= nil, "tile returned to origin")
    assert(scene.grid:get(4, 4).params.scalar == 3, "params preserved on cancel")
    print("PASS: right-click cancel preserves tile params")
end

-- Locked tiles cannot be lifted.
do
    local scene = new_scene()
    local source_x, source_y = scene.puzzle.source.x, scene.puzzle.source.y
    select_drag(scene)
    local sx = 130 + (source_x - 1) * 52 + 10
    local sy = 10 + (source_y - 1) * 52 + 10
    scene:mouse_pressed(sx, sy, 1)
    assert(scene._drag_tile == nil, "locked source tile cannot be lifted")
    print("PASS: locked tiles cannot be dragged")
end

-- Drag is blocked while simulation is running.
do
    local scene = new_scene()
    scene:_place_tile_at(3, 3, { kind = "op", op = "negate" })
    scene.running = true
    select_drag(scene)
    local sx = 130 + (3 - 1) * 52 + 10
    local sy = 10 + (3 - 1) * 52 + 10
    scene:mouse_pressed(sx, sy, 1)
    assert(scene._drag_tile == nil, "drag blocked while running")
    print("PASS: drag blocked during run")
end

-- Multi-cell op (scale_row, 1×4) lifts and drops as a unit.
-- Puzzle 1: source=(2,5) sink=(10,5), so place at (3,1) covering rows 1-4, col 3.
do
    local scene = new_scene()
    scene:_place_tile_at(3, 1, { kind = "op", op = "scale_row" })
    local tile = scene.grid:get(3, 1)
    assert(tile ~= nil and tile.op == "scale_row", "scale_row placed")
    local h = tile.height or 1
    assert(h > 1, "scale_row spans multiple rows")
    select_drag(scene)
    local sx = 130 + (3 - 1) * 52 + 10
    local sy = 10 + (1 - 1) * 52 + 10
    scene:mouse_pressed(sx, sy, 1)
    assert(scene._drag_tile ~= nil, "multi-cell tile lifted")
    assert(scene._drag_tile.op == "scale_row", "correct tile")
    -- All cells in its original footprint should be nil
    for dy = 0, h - 1 do
        assert(scene.grid.cells[1 + dy][3] == nil, "row " .. (1 + dy) .. " cleared")
    end
    -- Drop at (6, 1)
    scene:mouse_moved(130 + (6 - 1) * 52 + 10, 10 + (1 - 1) * 52 + 10)
    scene:mouse_released(130 + (6 - 1) * 52 + 10, 10 + (1 - 1) * 52 + 10, 1)
    assert(scene.grid:get(6, 1) ~= nil, "tile at new anchor")
    assert(scene.grid:get(6, 1).op == "scale_row", "correct tile at new location")
    print("PASS: multi-cell tile drag")
end

print("ALL TESTS PASSED")
