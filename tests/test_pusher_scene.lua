local runner = require("lua/headless/runner")

local Matrix = require("lua/game/matrix_math")

local function new_scene(puzzle_index)
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(puzzle_index or 1) end)
    return ctx.sm.current
end

-- Place a pusher and program its timeline slots (slots = { [slot] = "right", ... }).
local function add_pusher(scene, x, y, slots)
    scene:_place_tile_at(x, y, { kind = "pusher" })
    local id = scene.grid:get(x, y).id
    for s, cmd in pairs(slots) do scene.timeline[id][s] = cmd end
    return id
end

local function run_to_end(scene)
    scene:start_run()
    for _ = 1, 600 do
        if not scene.running then break end
        scene:do_step()
    end
end

-- Puzzle 1: 2x2 identity from source (2,5) to sink (10,5). A pusher starts just left
-- of the source and pushes the matrix right until it hits the sink.
local function carry(scene)
    add_pusher(scene, 1, 6, { "right", "right", "right", "right", "right", "right", "right", "right" })
end

do
    local scene = new_scene()
    carry(scene)
    run_to_end(scene)
    assert(scene.status == "win", "pusher carries the matrix to the sink, got " .. tostring(scene.status))
    assert(scene.sim.x == 9, "matrix right edge touches the sink, anchor x=" .. scene.sim.x)
    local p = scene.sim.pushers[1]
    assert(p.x == 8 and p.y == 6, "pusher moved with the matrix, at " .. p.x .. "," .. p.y)
    assert(scene.grid:get(1, 6).kind == "pusher", "placed tile still marks the start")
    print("PASS: pusher carries matrix to sink")
end

-- An op tile on the path fires exactly once, changing the result.
do
    local scene = new_scene()
    carry(scene)
    scene:_place_tile_at(5, 5, { kind = "op", op = "negate" })
    run_to_end(scene)
    assert(scene.status == "fail", "negate makes identity mismatch, got " .. tostring(scene.status))
    assert(scene.current_matrix.values[1][1] == -1, "negate fired exactly once")
    print("PASS: op fires once on path")
end

-- No pushers: matrix never moves and the run reports stuck after one timeline loop.
do
    local scene = new_scene()
    run_to_end(scene)
    assert(scene.status == "stuck", "idle run is stuck, got " .. tostring(scene.status))
    assert(scene.sim.tick == scene.timeline_n, "stuck after one full timeline")
    print("PASS: idle run is stuck")
end

-- Pusher ids are the lowest free letter and cap at 8.
do
    local scene = new_scene()
    for i = 1, 8 do scene:_place_tile_at(i, 2, { kind = "pusher" }) end
    scene:_place_tile_at(1, 3, { kind = "pusher" })
    assert(scene.grid:get(1, 3) == nil, "9th pusher is rejected")
    scene.grid:clear(3, 2)
    scene:_place_tile_at(1, 3, { kind = "pusher" })
    assert(scene.grid:get(1, 3).id == 3, "freed id 3 is reused")
    print("PASS: pusher ids")
end

-- Timeline clicks cycle a slot and resize the timeline; clicks are ignored mid-run.
do
    local scene = new_scene()
    local id = add_pusher(scene, 1, 6, {})
    scene._tl_top = 500
    local L = scene:_timeline_layout()
    local slot1 = L.rows[1].slots[1]
    scene:mouse_pressed(slot1.x + 1, slot1.y + 1, 1)
    assert(scene.timeline[id][1] == "up", "left-click cycles forward from idle to up")
    scene:mouse_pressed(slot1.x + 1, slot1.y + 1, 2)
    assert(scene.timeline[id][1] == "idle", "right-click cycles back")
    scene:mouse_pressed(L.inc.x + 1, L.inc.y + 1, 1)
    assert(scene.timeline_n == 9, "+ lengthens timeline")
    scene.running = true
    scene:mouse_pressed(L.inc.x + 1, L.inc.y + 1, 1)
    assert(scene.timeline_n == 9, "timeline locked while running")
    print("PASS: timeline editing")
end

-- No puzzle starts its matrix on the grid edge (room for a pusher behind it).
do
    local PuzzleLoader = require("lua/game/puzzle_loader")
    for i = 1, PuzzleLoader.count() do
        local pz = PuzzleLoader.load(i)
        assert(pz.source.x > 1 and pz.source.y > 1 and pz.source.x < pz.grid_w and pz.source.y < pz.grid_h,
            "puzzle " .. i .. " source is on the edge")
    end
    print("PASS: sources off the edge")
end

-- The palette only offers the ops a puzzle lists (pusher and erase always stay).
do
    local function labels(scene)
        local out = {}
        for _, r in pairs(scene._btn_rects) do out[r.btn.label] = true end
        return out
    end
    local scene = new_scene()
    local l = labels(scene)
    assert(l["P"] and l["[X]"] and l["T"] and l["-I"], "puzzle 1 offers all ops")
    scene:load_puzzle(2)
    l = labels(scene)
    assert(l["T"] and not l["xR"] and not l["R+R"], "puzzle 2 offers only transpose")
    scene.palette:select({ kind = "op", op = "transpose" })
    scene:load_puzzle(4)
    assert(scene.palette:selected() == nil, "selection of a now-hidden op is cleared")
    assert(labels(scene)["<>R"], "puzzle 4 offers swap rows")
    print("PASS: per-puzzle palette")
end

-- Pressing R or Space without a pusher sets status=no_pusher and does not start the run.
do
    local scene = new_scene()
    scene:key_pressed("r")
    assert(scene.status == "no_pusher", "R without pusher sets no_pusher, got " .. tostring(scene.status))
    assert(scene.sim == nil, "sim not created when no pusher")
    scene:key_pressed("space")
    assert(scene.status == "no_pusher", "Space without pusher keeps no_pusher")
    assert(scene.sim == nil, "sim still nil")
    -- After placing a pusher the guard clears and the run starts.
    add_pusher(scene, 1, 6, { "right", "right", "right", "right", "right", "right", "right", "right" })
    scene:key_pressed("r")
    assert(scene.status == "running" or scene.sim ~= nil, "run starts once a pusher is placed")
    print("PASS: no_pusher guard")
end

-- A pusher that walks into the grid wall is a blocked move → puzzle fail.
do
    local scene = new_scene()
    add_pusher(scene, 1, 6, { "left" })
    run_to_end(scene)
    assert(scene.status == "fail", "blocked pusher (wall) fails run, got " .. tostring(scene.status))
    print("PASS: blocked pusher wall fails run")
end

-- A pusher that tries to shove the matrix off the grid is a blocked move → puzzle fail.
-- Push the 2x2 matrix from (2,5) down 5 times; on tick 5 the matrix is at (2,9) and
-- shoving it to (2,10) would put row 11 off the grid.
do
    local scene = new_scene()
    add_pusher(scene, 2, 4, { "down", "down", "down", "down", "down" })
    run_to_end(scene)
    assert(scene.status == "fail", "blocked pusher (matrix at wall) fails run, got " .. tostring(scene.status))
    print("PASS: blocked pusher matrix-at-wall fails run")
end

-- Fixed player-placed tile has fixed=true and param edits are blocked.
do
    local scene = new_scene()
    -- Place a swap_rows tile with fixed=true directly.
    scene:_place_tile_at(5, 5, { kind="op", op="swap_rows", fixed=true })
    local tile = scene.grid:get(5, 5)
    assert(tile ~= nil, "fixed swap_rows placed")
    assert(tile.fixed == true, "tile.fixed is true, got " .. tostring(tile.fixed))
    assert(tile.params.row_a == 1, "default row_a=1, got " .. tostring(tile.params.row_a))

    -- Simulate clicking the right-third of the first strip (dc=0, would normally increment row_a).
    -- GRID_X=95, CELL_SIZE=63: sx = 95+(5-1)*63 = 347, sy = 20+(5-1)*63 = 272
    -- Right-third x: 347 + 42 = 389+, use 395; strip-1 y mid: 272+32 = 304
    scene:mouse_pressed(395, 304, 1)
    assert(tile.params.row_a == 1,
        "fixed tile param unchanged after click, got row_a=" .. tostring(tile.params.row_a))
    print("PASS: fixed player-placed tile blocks param edits")
end

-- Puzzle-placed locked op loads as a multi-cell tile (scale_row spans 4 rows).
do
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(23) end)
    local scene = ctx.sm.current

    -- Anchor at (5,3)
    local anchor = scene.grid:get(5, 3)
    assert(anchor ~= nil, "locked scale_row anchor present at (5,3)")
    assert(anchor.kind == "op",    "anchor kind=op, got " .. tostring(anchor.kind))
    assert(anchor.op   == "scale_row", "anchor op=scale_row, got " .. tostring(anchor.op))
    assert(anchor.locked == true,  "anchor is locked")
    assert(anchor.params.scalar == 3, "anchor scalar=3, got " .. tostring(anchor.params.scalar))

    -- Ref cells at rows 4, 5, 6 (tile_rows=4 → rows 3..6)
    local ok4, ax4, ay4 = scene.grid:is_ref(5, 4)
    assert(ok4 and ax4==5 and ay4==3, "row 4 is ref → anchor (5,3)")
    local ok5, ax5, ay5 = scene.grid:is_ref(5, 5)
    assert(ok5 and ax5==5 and ay5==3, "row 5 is ref → anchor (5,3)")
    local ok6, ax6, ay6 = scene.grid:is_ref(5, 6)
    assert(ok6 and ax6==5 and ay6==3, "row 6 is ref → anchor (5,3)")

    -- Row 2 (y=4 in grid coords is *above* the tile, i.e. y=2 in grid) should be empty.
    local ok2 = scene.grid:is_ref(5, 2)
    assert(not ok2, "row above tile (5,2) is not a ref")

    print("PASS: locked multi-cell op loads correctly")
end

-- Puzzle-placed locked op fires with correct params in simulation.
do
    local Sim = require("lua/game/pusher_sim")
    local Matrix = require("lua/game/matrix_math")
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(23) end)
    local scene = ctx.sm.current

    local tile = scene.grid:get(5, 3)
    local inp  = Matrix.new(2, 2, {{1,2},{3,4}})
    local out  = Sim.apply_op(tile, inp)
    -- scale_row(row=1, scalar=3): row 1 → {3,6}; row 2 unchanged
    assert(out.values[1][1] == 3, "scale_row row1 col1 = 3, got " .. tostring(out.values[1][1]))
    assert(out.values[1][2] == 6, "scale_row row1 col2 = 6, got " .. tostring(out.values[1][2]))
    assert(out.values[2][1] == 3, "scale_row row2 col1 unchanged = 3, got " .. tostring(out.values[2][1]))
    assert(out.values[2][2] == 4, "scale_row row2 col2 unchanged = 4, got " .. tostring(out.values[2][2]))
    print("PASS: locked op fires with correct params")
end

-- Timeout: a pusher that oscillates (right/left) moves every tick so it never
-- triggers "stuck", but after 500 ticks the sim hits MAX_TICKS → "timeout".
do
    local scene = new_scene()
    scene.timeline_n = 2
    add_pusher(scene, 5, 2, { "right", "left" })
    run_to_end(scene)
    assert(scene.status == "timeout",
        "oscillating pusher times out after 500 ticks, got " .. tostring(scene.status))
    assert(scene.sim.tick >= 500,
        "sim ran at least 500 ticks, got " .. tostring(scene.sim.tick))
    print("PASS: timeout status")
end

-- A dimension-changing op (transpose on a non-square matrix) must not wrongly
-- trigger sibling ops that are no longer under the matrix after the size change.
--
-- Setup: puzzle 5 has a 2×3 input matrix (2 rows, 3 cols).  Source at (2,3).
-- A pusher moves the matrix right 3 cells until it reaches (5,3), where the
-- rightmost column of its footprint — cells (7,3) and (7,4) — is newly entered.
-- Transpose at (7,3) fires first (top-to-bottom order) and reshapes the matrix
-- from 2×3 to 3×2.  The 3×2 footprint at (5,3) covers only cols 5-6, so (7,4)
-- is no longer under the matrix.  Negate at (7,4) must NOT fire.
do
    local scene = new_scene(5)   -- input: 2×3  {{1,2,3},{4,5,6}}
    add_pusher(scene, 1, 3, { [1]="right", [2]="right", [3]="right" })
    scene:_place_tile_at(7, 3, { kind="op", op="transpose" })
    scene:_place_tile_at(7, 4, { kind="op", op="negate" })
    scene:start_run()
    scene:do_step(); scene:do_step(); scene:do_step()
    -- Only transpose should have fired: 2×3 → transposed 3×2 = {{1,4},{2,5},{3,6}}
    local expected = Matrix.new(3, 2, {{1,4},{2,5},{3,6}})
    assert(scene.current_matrix:equals(expected),
        "negate at (7,4) must not fire after transpose shrinks matrix off that cell")
    print("PASS: dimension-changing op does not wrongly trigger co-entered sibling op")
end

print("ALL TESTS PASSED")
