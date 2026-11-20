-- test_solution_recap.lua
-- Tests for the solution recap screen feature:
--   - run_frames are recorded during a winning run
--   - _count_pieces counts only player-placed (non-locked) anchor tiles
--   - on win, scene switches to SolutionRecapScene (not LevelSelectScene)

local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
    return ctx.sm.current
end

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

-- After a successful run, _run_frames should contain at least one frame.
do
    local scene = new_scene()
    add_pusher(scene, 1, 6, { "right", "right", "right", "right", "right", "right", "right", "right" })
    run_to_end(scene)
    assert(scene.status == "win", "precondition: run wins")
    assert(type(scene._run_frames) == "table", "_run_frames is a table")
    assert(#scene._run_frames > 0, "_run_frames has at least one frame, got " .. tostring(#scene._run_frames))
    local f = scene._run_frames[1]
    assert(f.from_x ~= nil and f.from_y ~= nil, "frame has from_x/from_y")
    assert(f.to_x   ~= nil and f.to_y   ~= nil, "frame has to_x/to_y")
    assert(f.matrix ~= nil and f.matrix.values ~= nil, "frame has a matrix snapshot")
    assert(type(f.pushers_from) == "table", "frame has pushers_from table")
    assert(type(f.pushers_to)   == "table", "frame has pushers_to table")
    assert(#f.pushers_from >= 1, "pushers_from has at least one entry (pusher was placed)")
    local pf = f.pushers_from[1]
    assert(pf.id ~= nil and pf.px ~= nil and pf.py ~= nil, "pushers_from entry has id/px/py fields")
    -- Frames are independent copies: mutating the scene matrix should not affect the frame.
    local orig_val = f.matrix.values[1][1]
    scene.current_matrix.values[1][1] = orig_val + 999
    assert(f.matrix.values[1][1] == orig_val, "frame matrix is a deep copy")
    print("PASS: run_frames recorded correctly")
end

-- _run_frames is cleared (reset) on each new run start.
do
    local scene = new_scene()
    add_pusher(scene, 1, 6, { "right", "right", "right", "right", "right", "right", "right", "right" })
    run_to_end(scene)
    local first_count = #scene._run_frames
    assert(first_count > 0, "precondition: first run captured frames")
    scene:do_reset()
    run_to_end(scene)
    assert(#scene._run_frames == first_count, "second run captures the same number of frames")
    print("PASS: run_frames reset on each start_run")
end

-- _count_pieces counts non-locked placed tiles (pushers, ops), not source/sink/gaps.
do
    local scene = new_scene()
    -- No player-placed tiles yet (source and sink are locked).
    assert(scene:_count_pieces() == 0, "empty board has 0 pieces")

    add_pusher(scene, 1, 6, {})
    assert(scene:_count_pieces() == 1, "one pusher = 1 piece")

    scene:_place_tile_at(5, 5, { kind = "op", op = "negate" })
    assert(scene:_count_pieces() == 2, "pusher + negate = 2 pieces")

    -- A multi-cell op tile (scale_row spans 4 rows) should count as 1 piece.
    scene:_place_tile_at(7, 1, { kind = "op", op = "scale_row" })
    assert(scene:_count_pieces() == 3, "multi-cell scale_row counts as 1 piece, not 4")

    print("PASS: _count_pieces")
end

-- After a win, the scene switches to SolutionRecapScene (not LevelSelectScene).
do
    local MatrixScene = require("lua/game/scenes/matrix_scene")
    local ctx = runner.setup(function(_, sm) return MatrixScene.new(1, sm) end)
    local scene = ctx.sm.current
    add_pusher(scene, 1, 6, { "right", "right", "right", "right", "right", "right", "right", "right" })
    run_to_end(scene)
    assert(scene.status == "win", "precondition: run wins")

    -- Advance enough time to trigger the win transition (needs >= 0.8 s).
    ctx.sm:update(1.0)

    local new_scene_obj = ctx.sm.current
    -- The scene should have switched; check it is a SolutionRecapScene by duck-typing.
    assert(new_scene_obj ~= scene, "scene switched after win")
    assert(type(new_scene_obj._stats) == "table", "new scene has _stats (SolutionRecapScene)")
    assert(new_scene_obj._stats.ticks > 0, "stats.ticks populated, got " .. tostring(new_scene_obj._stats.ticks))
    assert(new_scene_obj._stats.pieces >= 1, "stats.pieces >= 1, got " .. tostring(new_scene_obj._stats.pieces))
    assert(new_scene_obj._stats.puzzle_index == 1, "stats.puzzle_index = 1")
    assert(type(new_scene_obj._frames) == "table" and #new_scene_obj._frames > 0, "frames passed to recap scene")
    print("PASS: win transitions to SolutionRecapScene")
end

-- SolutionRecapScene replay loop: frame_idx advances over time and loops back.
do
    local SolutionRecapScene = require("lua/game/scenes/solution_recap_scene")

    -- Build minimal fake frames.
    local Matrix = require("lua/game/matrix_math")
    local mat = Matrix.new(1, 1, {{1}})
    local frames = {}
    for i = 1, 4 do
        frames[i] = { from_x=0, from_y=0, to_x=10*i, to_y=0, matrix=mat }
    end

    local stats = { ticks=10, pieces=2, puzzle_name="Test", puzzle_index=1 }
    local board = {}
    local recap = SolutionRecapScene.new(stats, board, frames, 0.1, nil)

    assert(recap._frame_idx == 1, "starts at frame 1")
    recap:update(0.15)  -- > one run_speed (0.1) → should advance to frame 2
    assert(recap._frame_idx == 2, "frame advances after run_speed elapsed, got " .. tostring(recap._frame_idx))

    -- Run past the last frame.
    for _ = 1, 20 do recap:update(0.15) end
    -- Should be holding at the last frame or have looped back.
    assert(recap._frame_idx <= #frames, "frame_idx stays within bounds")
    -- After the hold expires, it should reset to frame 1.
    recap:update(1.0)  -- well past PAUSE_AT_END
    assert(recap._frame_idx == 1, "loops back to frame 1 after hold, got " .. tostring(recap._frame_idx))
    print("PASS: SolutionRecapScene replay loop")
end

-- Frame matrix shows PRE-op values: the frame recorded for the step that moves
-- the matrix into an op tile must carry the values BEFORE the op fires.
do
    -- Puzzle 3 (negate): 2×2 input [[1,-2],[3,0]], source (2,5), sink (10,5).
    local ctx3 = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(3) end)
    local scene3 = ctx3.sm.current

    -- Pusher at (1,6) pushes the matrix one cell right per tick.
    add_pusher(scene3, 1, 6, { "right","right","right","right","right","right","right","right" })
    -- Negate op at (8,5): the 2×2 matrix first covers (8,5) on step 5
    -- (top-left at (7,5), right column = col 8).
    scene3:_place_tile_at(8, 5, { kind="op", op="negate" })
    run_to_end(scene3)
    assert(scene3.status == "win",
        "precondition: negate run wins, got " .. tostring(scene3.status))

    local frames3 = scene3._run_frames
    -- Frame 5 is the step entering (7,5), which newly covers (8,5) where the negate fires.
    -- The fix requires this frame to hold the PRE-negate matrix (values[1][1] == 1).
    local nf = frames3[5]
    assert(nf ~= nil, "frame 5 exists")
    local v = nf.matrix.values[1][1]
    assert(v == 1, "frame entering negate op carries pre-op value (1), got " .. tostring(v))
    -- The following frame (top-left at (8,5), no new op) must carry the POST-negate value.
    local pf = frames3[6]
    assert(pf ~= nil, "frame 6 exists")
    local v2 = pf.matrix.values[1][1]
    assert(v2 == -1, "frame after negate op carries post-op value (-1), got " .. tostring(v2))
    print("PASS: frame matrix shows pre-op values (not one step early)")
end

-- SolutionRecapScene draw: exercises _draw_tile for op/gap kinds and _draw_buttons.
do
    local SolutionRecapScene = require("lua/game/scenes/solution_recap_scene")
    local Grid   = require("lua/game/grid")
    local Matrix = require("lua/game/matrix_math")

    -- Build a 4×4 grid with one gap tile, one op tile, one source, one sink.
    local grid = Grid.new(4, 4)
    grid.cells[1][1] = { kind = "gap" }
    grid.cells[1][2] = { kind = "op", op = "scale_row", width = 1, height = 1 }
    grid.cells[1][3] = { kind = "source", width = 1, height = 1 }
    grid.cells[1][4] = { kind = "sink" }
    -- Add a pusher so _draw_tile pusher branch runs.
    grid.cells[2][1] = { kind = "pusher", id = 1 }

    local board = { grid = grid }

    local mat = Matrix.new(1, 1, {{7}})
    local frames = {
        {
            from_x = 95, from_y = 20, to_x = 95, to_y = 20,
            matrix = mat,
            pushers_from = { { id = 1, px = 95, py = 83 } },
            pushers_to   = { { id = 1, px = 95, py = 83 } },
        },
    }

    local stats = { ticks = 5, pieces = 1, puzzle_name = "Draw Test", puzzle_index = 1 }
    local recap  = SolutionRecapScene.new(stats, board, frames, 0.1, nil)
    recap:on_enter()

    -- First draw: _frame_idx=1, _anim_t=0 — covers all draw helpers including
    -- op, gap, source, sink, pusher kinds in _draw_tile and the pushers_from path.
    recap:draw()

    -- Advance into _holding, then draw while holding (covers _end_hold countdown path visually).
    -- With run_speed=0.1 and dt=0.15 each tick advances the frame immediately; after 1 tick
    -- _holding becomes true. PAUSE_AT_END=0.6s and dt=0.15 means hold expires after 4 more
    -- ticks, so we stop at 4 total to stay within the hold window.
    for _ = 1, 4 do recap:update(0.15) end
    assert(recap._holding, "should be holding after advancing past single frame")
    recap:draw()

    -- Expire the hold so _frame_idx resets to 1 (loop-back), then draw once more.
    recap:update(1.0)
    assert(not recap._holding, "hold expired")
    assert(recap._frame_idx == 1, "loop-back to frame 1, got " .. tostring(recap._frame_idx))
    recap:draw()

    print("PASS: SolutionRecapScene draw (op/gap/source/sink/pusher tiles + loop-back)")
end

print("ALL TESTS PASSED")
