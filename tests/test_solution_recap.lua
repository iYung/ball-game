-- test_solution_recap.lua
-- Tests for the solution recap screen feature:
--   - run_frames are recorded during a winning run
--   - _count_pieces counts only player-placed (non-locked) anchor tiles
--   - on win, scene switches to SolutionRecapScene (not LevelSelectScene)

local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("game/scenes/matrix_scene").new(1) end)
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
    local MatrixScene = require("game/scenes/matrix_scene")
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
    local SolutionRecapScene = require("game/scenes/solution_recap_scene")

    -- Build minimal fake frames.
    local Matrix = require("game/matrix_math")
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

print("ALL TESTS PASSED")
