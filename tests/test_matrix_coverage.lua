-- test_matrix_coverage.lua
-- Covers remaining uncovered lines in lua/game/scenes/matrix_scene.lua:
--   Lines 573-576  (fail status when Sim.footprint_clear returns false after op)
--   Lines 637, 639 (timeline auto-scroll forward / backward during a run)
--   Line 878       (op-tile ghost preview label)
--   Lines 1051-1053 (tile.fixed draw indicator)
--   Lines 1284, 1320 (float matrix values in input preview and animated draw)
--   Lines 1352-1355 (_cmd_activate "menu")
--   Line 1408       (_palette_select erase)
--   Lines 1744-1745 (mul_matrix placement tile_rows/tile_cols/values init)
--   Lines 1846-1847 (drag ghost cleared when in grid panel but out of grid bounds)
--   Lines 1976-1984 (set_row value-cell click when dc != 0)
--   Line 2113       (grid:clear called when palette nil and clicking empty cell)

local runner  = require("lua/headless/runner")
local Matrix  = require("lua/game/matrix_math")
local Grid    = require("lua/game/grid")

-- GRID_X=95, GRID_Y=20, CELL_SIZE=63 (from matrix_scene.lua)
local GRID_X, GRID_Y, CELL_SIZE = 95, 20, 63

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
    return ctx.sm.current
end

-- Helper: pixel centre of grid cell (cx, cy)
local function cell_px(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE + math.floor(CELL_SIZE / 2),
           GRID_Y + (cy - 1) * CELL_SIZE + math.floor(CELL_SIZE / 2)
end

-- ── 1. Fail status: footprint_clear returns false after op fires ──────────────
-- Lines 573-576
do
    local scene = new_scene()
    local Sim   = require("lua/game/pusher_sim")

    -- Place a negate op at (5, 5)
    scene:_place_tile_at(5, 5, { kind = "op", op = "negate" })

    -- Manually configure sim: matrix at (5,5), pusher also at (5,5).
    -- After negate fires the matrix is still 2x2 at (5,5); the pusher at (5,5)
    -- overlaps the footprint → footprint_clear returns false → lines 573-576.
    scene.current_matrix = Matrix.new(2, 2, {{1,0},{0,1}})
    scene.running        = true
    scene.sim            = { x=5, y=5, pushers={{x=5, y=5}}, gaps={} }
    scene.occupied_ops   = {}
    scene._last_fp       = {}

    local ok, err = pcall(function() scene:_process_footprint({}) end)
    assert(ok, "_process_footprint with overlapping pusher threw: " .. tostring(err))
    assert(scene.running == false, "fail: running must be false")
    assert(scene.status  == "blocked", "fail: status must be 'blocked', got " .. tostring(scene.status))

    print("PASS: blocked status when footprint_clear returns false after op (lines 573-576)")
end

-- ── 2a. Timeline auto-scroll forward (line 637) ──────────────────────────────
-- Requires timeline_n > vis (vis == 12 for the standard layout).
-- With timeline_n=13 and an idle pusher, step 13 gives cur_slot=13 > 0+12.
do
    local scene = new_scene()

    -- Place a pusher so the timeline has at least one row
    scene:_place_tile_at(1, 5, { kind = "pusher", id = 1 })

    -- Set _tl_top so _timeline_layout() returns a table (normally set by draw)
    scene._tl_top    = 400
    scene.timeline_n = 13   -- one more than vis (12)

    scene:start_run()

    -- Advance 13 steps; at step 13 cur_slot=13 > scroll(0)+vis(12) → line 637
    for _ = 1, 13 do
        scene.anim_ready = true
        scene:do_step()
    end

    assert((scene.timeline_scroll or 0) >= 1,
        "timeline should have scrolled forward (line 637), scroll=" .. tostring(scene.timeline_scroll))
    print("PASS: timeline auto-scroll forward (line 637)")
end

-- ── 2b. Timeline auto-scroll backward (line 639) ─────────────────────────────
-- After the first step cur_slot==1 → line 635 sets scroll=0.
-- Manually bump scroll forward, then take another step so cur_slot<=scroll.
do
    local scene = new_scene()

    scene:_place_tile_at(1, 5, { kind = "pusher", id = 1 })
    scene._tl_top    = 400
    scene.timeline_n = 2    -- keeps idle-stuck quick; vis=12 so no forward scroll

    scene:start_run()

    -- Step 1: tick=1, cur_slot=1 → line 635 fires, scroll reset to 0
    scene.anim_ready = true
    scene:do_step()
    assert(scene.cur_slot == 1, "cur_slot should be 1 after step 1")

    -- Manually scroll forward past the upcoming cur_slot
    scene.timeline_scroll = 2

    -- Step 2: tick=2, cur_slot=2 ≤ scroll(2) → line 639 fires → scroll = cur_slot-1 = 1
    -- (run ends due to stuck: idle==2 >= timeline_n==2, but scroll check runs first)
    scene.anim_ready = true
    scene:do_step()

    assert((scene.timeline_scroll or 0) < 2,
        "timeline should have scrolled back (line 639), scroll=" .. tostring(scene.timeline_scroll))
    print("PASS: timeline auto-scroll backward (line 639)")
end

-- ── 3. Op-tile ghost preview label (line 878) ─────────────────────────────────
-- The existing test_matrix_draw.lua uses a pusher ghost (line 876).
-- Line 878 fires when the dragged tile is a non-pusher op tile.
do
    local scene = new_scene()
    scene._drag_tile  = { kind = "op", op = "negate", width = 1, height = 1 }
    scene._drag_ghost = { cx = 5, cy = 1 }

    local ok, err = pcall(function() scene:draw_grid() end)
    assert(ok, "draw_grid with op ghost threw: " .. tostring(err))
    print("PASS: op-tile ghost preview label (line 878)")
end

-- ── 4. tile.fixed draw indicator (lines 1051-1053) ───────────────────────────
do
    local scene = new_scene()

    -- Place an op tile then set it fixed
    scene:_place_tile_at(5, 1, { kind = "op", op = "negate" })
    local tile = scene.grid:get(5, 1)
    tile.fixed = true

    local ok, err = pcall(function() scene:draw_grid() end)
    assert(ok, "draw_grid with fixed tile threw: " .. tostring(err))
    print("PASS: tile.fixed draw indicator (lines 1051-1053)")
end

-- ── 5a. Float matrix value in input preview (line 1284) ──────────────────────
-- draw_travelling_matrix shows input_matrix when sim==nil and current_matrix==nil.
-- Line 1284 fires when a matrix value is not an integer.
do
    local scene = new_scene()
    -- Inject a float value directly into input_matrix
    scene.input_matrix = Matrix.new(1, 1, {{0.5}})
    scene:_place_tile_at(5, 1, { kind = "pusher" })

    local ok, err = pcall(function() scene:draw_travelling_matrix() end)
    assert(ok, "draw_travelling_matrix (input preview float) threw: " .. tostring(err))
    print("PASS: float input-preview matrix value (line 1284)")
end

-- ── 5b. Float matrix value in animated draw (line 1320) ──────────────────────
-- Line 1320 fires when current_matrix has a non-integer value (during animation).
do
    local scene = new_scene()
    scene.current_matrix = Matrix.new(1, 1, {{0.5}})
    -- Set up the animation state so the main draw path is taken
    scene.anim_t      = 0.5
    scene.anim_from_x = GRID_X
    scene.anim_from_y = GRID_Y
    scene.anim_to_x   = GRID_X + CELL_SIZE
    scene.anim_to_y   = GRID_Y

    local ok, err = pcall(function() scene:draw_travelling_matrix() end)
    assert(ok, "draw_travelling_matrix (animated float) threw: " .. tostring(err))
    print("PASS: float animated matrix value (line 1320)")
end

-- ── 6. _cmd_activate "menu" (lines 1352-1355) ─────────────────────────────────
do
    local scene = new_scene()
    local LevelSelectScene = require("lua/game/scenes/level_select_scene")

    local switched_to = nil
    local mock_sm = {
        switch = function(_, s) switched_to = s end
    }
    scene._scene_manager = mock_sm

    local ok, err = pcall(function() scene:_cmd_activate("menu") end)
    assert(ok, "_cmd_activate('menu') threw: " .. tostring(err))
    assert(switched_to ~= nil, "_cmd_activate('menu') should have called sm:switch")
    assert(getmetatable(switched_to) == LevelSelectScene,
        "_cmd_activate('menu') should switch to a LevelSelectScene")
    print("PASS: _cmd_activate('menu') switches to LevelSelectScene (lines 1352-1355)")
end

-- ── 7. _palette_select erase (line 1408) ──────────────────────────────────────
do
    local scene = new_scene()
    -- Select a pusher first so the palette has something selected
    scene.palette:select({ kind = "pusher" })
    assert(scene.palette:selected() ~= nil, "pre-condition: palette should have selection")

    local ok, err = pcall(function() scene:_palette_select({ erase = true }) end)
    assert(ok, "_palette_select({erase=true}) threw: " .. tostring(err))
    assert(scene.palette:selected() == nil, "_palette_select erase should clear selection")
    print("PASS: _palette_select({erase=true}) clears palette (line 1408)")
end

-- ── 8. mul_matrix placement: tile_rows=1, tile_cols=1, values={{1}} (lines 1744-1745) ──
do
    local scene = new_scene()

    local ok, err = pcall(function()
        scene:_place_tile_at(5, 5, { kind = "op", op = "mul_matrix" })
    end)
    assert(ok, "_place_tile_at mul_matrix threw: " .. tostring(err))

    local tile = scene.grid:get(5, 5)
    assert(tile ~= nil,          "mul_matrix: tile should exist at (5,5)")
    assert(tile.tile_rows == 1,  "mul_matrix: tile_rows should be 1")
    assert(tile.tile_cols == 1,  "mul_matrix: tile_cols should be 1")
    assert(tile.values ~= nil and tile.values[1] ~= nil and tile.values[1][1] == 1,
        "mul_matrix: values[1][1] should be 1")
    print("PASS: mul_matrix placement sets tile_rows=1, tile_cols=1, values={{1}} (lines 1744-1745)")
end

-- ── 9. Drag ghost cleared when in-panel but cell is out of bounds (lines 1846-1847) ──
-- Requires a grid smaller than the 10×10 panel.  Replace grid.w/h with 5×5 so
-- any cell >= 6 is out of bounds while still being inside the visual panel.
do
    local scene = new_scene()
    scene._drag_tile = { kind = "op", op = "negate", width = 1, height = 1 }

    -- Shrink the logical grid to 5×5; panel is still 10-cell wide (95..724)
    scene.grid = Grid.new(5, 5)

    -- Pre-set a ghost so we can confirm it gets cleared
    scene._drag_ghost = { cx = 3, cy = 3 }

    -- Mouse at cell (6, 1) — inside panel (95+5*63=410 < 725) but cx=6 > grid.w=5
    local mx = GRID_X + (6 - 1) * CELL_SIZE + 10   -- 95+315+10 = 420
    local my = GRID_Y + (1 - 1) * CELL_SIZE + 10   -- 20+0+10   = 30

    local ok, err = pcall(function() scene:mouse_moved(mx, my) end)
    assert(ok, "mouse_moved out-of-bounds cell threw: " .. tostring(err))
    assert(scene._drag_ghost == nil,
        "drag ghost should be nil when cell is out of grid bounds (lines 1846-1847)")
    print("PASS: drag ghost cleared when in-panel but cell out of bounds (lines 1846-1847)")
end

-- ── 10. set_row value-cell click with dc != 0 (lines 1976-1984) ──────────────
-- Place a set_row tile, grow it one column so there is a ref cell, then click
-- the ref cell so dc = cx - ax = 1 ≠ 0 → lines 1976-1984 fire.
-- Use (5,1) — puzzle 1 source is at (2,5)/(3,5)/(2,6)/(3,6) so (5,1) is free.
do
    local scene = new_scene()

    -- Place set_row at (5, 1)
    scene:_place_tile_at(5, 1, { kind = "op", op = "set_row" })
    -- Grow by one column → ref cell now lives at (6, 1)
    scene:_resize_tile(5, 1, "grow_col")

    local tile = scene.grid:get(5, 1)
    assert(tile ~= nil and tile.op == "set_row", "set_row tile must be at (5,1)")
    local is_r = scene.grid:is_ref(6, 1)
    assert(is_r, "ref cell must exist at (6,1) after grow_col")

    -- Select a non-eraser palette item so the eraser branch (line 1933) is skipped
    scene.palette:select({ kind = "op", op = "negate" })

    -- Click in the left third of the ref cell (6,1) → rel_x < CELL_SIZE/3 → decrement
    -- cell_top_left(6,1) = (95+5*63, 20+0*63) = (410, 20)
    -- left-third: mx in [410, 431) → use 411
    local mx, my = 411, 30

    local ok, err = pcall(function() scene:mouse_pressed(mx, my, 1) end)
    assert(ok, "mouse_pressed on set_row ref cell threw: " .. tostring(err))

    local values = tile.values
    assert(values and values[1] and values[1][1] ~= nil,
        "set_row value cell: values[1][1] should exist after click")
    -- Initial value is 0, clicking the left third decrements to max(-9, -1) = -1
    assert(values[1][1] == math.max(-9, -1),
        "set_row value cell: values[1][1] should be -1 after decrement, got " .. tostring(values[1][1]))
    print("PASS: set_row value-cell click with dc!=0 (lines 1976-1984)")
end

-- ── 11. grid:clear on empty cell when palette is nil (line 2113) ─────────────
-- palette:selected() == nil + clicking an empty cell that is NOT a ref cell
-- → spec==nil branch at line 2112 → grid:clear(cx, cy) at line 2113.
do
    local scene = new_scene()

    -- Ensure eraser mode (default is nil, but set explicitly for clarity)
    scene.palette:select(nil)
    assert(scene.palette:selected() == nil, "pre-condition: palette should be nil")

    -- Cell (8, 8) is empty on a fresh puzzle-1 scene
    assert(scene.grid:get(8, 8) == nil, "pre-condition: cell (8,8) should be empty")

    -- Click at the centre of cell (8, 8)
    -- cell_top_left(8,8) = (95+7*63, 20+7*63) = (536, 461)
    local mx, my = 536 + math.floor(CELL_SIZE / 2), 461 + math.floor(CELL_SIZE / 2)  -- ≈ 567, 492

    local ok, err = pcall(function() scene:mouse_pressed(mx, my, 1) end)
    assert(ok, "mouse_pressed on empty cell with nil palette threw: " .. tostring(err))
    -- grid:clear on an already-empty cell is a no-op (cell stays nil)
    assert(scene.grid:get(8, 8) == nil, "cell (8,8) should still be nil after clearing empty cell")
    print("PASS: grid:clear on empty cell with nil palette (line 2113)")
end

-- ── 12. _cmd_enabled with unknown id returns false (line 1369) ───────────────
do
    local scene = new_scene()
    local result = scene:_cmd_enabled("unknown_command")
    assert(result == false, "_cmd_enabled unknown id must return false, got: " .. tostring(result))
    print("PASS: _cmd_enabled unknown id returns false (line 1369)")
end

-- ── 13. _palette_is_selected with unknown kind returns false (line 1424) ──────
-- sel != nil, btn.kind does not match any handled kind → line 1424 fires.
do
    local scene = new_scene()
    -- Select something so palette:selected() != nil
    scene.palette:select({ kind = "op", op = "negate" })
    -- Pass a button whose kind is not "pusher", "drag", or "op"
    local result = scene:_palette_is_selected({ kind = "unknown_kind" })
    assert(result == false, "_palette_is_selected unknown kind must return false, got: " .. tostring(result))
    print("PASS: _palette_is_selected unknown kind returns false (line 1424)")
end

-- ── 14. set_row value-cell right-third click increments value (lines 2072-2073) ──
-- Same setup as test 10 but click the right third of the ref cell.
do
    local scene = new_scene()
    scene:_place_tile_at(5, 1, { kind = "op", op = "set_row" })
    scene:_resize_tile(5, 1, "grow_col")

    local tile = scene.grid:get(5, 1)
    assert(tile ~= nil and tile.op == "set_row", "set_row tile must be at (5,1)")
    scene.palette:select({ kind = "op", op = "negate" })

    -- Click the right third of ref cell (6,1):
    -- cell_top_left(6,1) = (95+5*63, 20+0*63) = (410, 20)
    -- right-third: rel_x >= CELL_SIZE*2/3 = 42 → mx >= 410+42 = 452 → use 455
    local mx, my = 455, 30

    local ok, err = pcall(function() scene:mouse_pressed(mx, my, 1) end)
    assert(ok, "mouse_pressed right-third of set_row ref cell threw: " .. tostring(err))

    local values = tile.values
    assert(values and values[1] and values[1][1] ~= nil,
        "set_row value cell: values[1][1] should exist after right-click")
    assert(values[1][1] == math.min(9, 1),
        "set_row value cell: values[1][1] should be 1 after increment, got " .. tostring(values[1][1]))
    print("PASS: set_row value-cell right-third click increments value (lines 2072-2073)")
end

print("ALL MATRIX COVERAGE TESTS PASSED")
