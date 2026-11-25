-- test_matrix_anim_timing.lua
-- The puzzle scene slides the matrix into an op with its PRE-op values (like the
-- solution recap) and shows the post-op values only once the slide has finished.

local S = require("tests/support/shipped")
local runner = require("lua/headless/runner")

local Timeline = require("lua/game/timeline")
local PRE    = { { 1, 2 }, { 3, 4 } }
local POST   = { { 1, 3 }, { 2, 4 } }

-- Puzzle 2: 2x2 matrix at (2,5), transpose offered. Op at (5,6) is entered on tick 2.
local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(S.puzzle("flip")) end)
    local scene = ctx.sm.current
    scene:_place_tile_at(5, 6, { kind = "op", op = "transpose" })
    scene:_place_tile_at(1, 5, { kind = "pusher" })
    local id = scene.grid:get(1, 5).id
    -- One persistent "right" command at tick 1 (the old test filled all 8 looping slots).
    Timeline.set(scene.timeline, 1, 1, id, "right")
    return scene
end

local function same(m, expected)
    for r = 1, #expected do
        for c = 1, #expected[r] do
            if m.values[r][c] ~= expected[r][c] then return false end
        end
    end
    return true
end

-- Sliding into the op shows pre-op values; the next slide and the resting state show post-op.
do
    local scene = new_scene()
    scene:start_run()
    scene:do_step()  -- tick 1: no op yet
    assert(same(scene:_display_matrix(), PRE), "tick 1 shows the input matrix")
    scene:do_step()  -- tick 2: enters the transpose tile
    assert(scene.anim_t == 0, "precondition: tick 2 is mid-slide")
    assert(same(scene.current_matrix, POST), "precondition: op already applied to game state")
    assert(same(scene:_display_matrix(), PRE), "sliding into the op shows the pre-op matrix")

    scene.anim_t = 0.5
    assert(same(scene:_display_matrix(), PRE), "still pre-op halfway through the slide")

    scene.anim_t = 1
    assert(same(scene:_display_matrix(), POST), "post-op matrix once the slide has finished")

    scene.anim_t = 0
    scene:do_step()  -- tick 3: slides away from the op carrying the transformed matrix
    assert(same(scene:_display_matrix(), POST), "next slide carries the post-op matrix")
    print("PASS: pre-op values while sliding into an op, post-op after")
end

-- update() drives the same sequence: the slide into the op ends, then post-op is shown.
do
    local scene = new_scene()
    scene:start_run()
    scene:update(0)                           -- tick 1
    scene:update(scene.run_speed)             -- finishes tick 1, starts tick 2 (enters op)
    assert(scene.anim_t == 0 and same(scene:_display_matrix(), PRE), "tick 2 slide shows pre-op")
    scene:update(scene.run_speed / 2)
    assert(same(scene:_display_matrix(), PRE), "mid-slide still pre-op via update")
    scene:update(scene.run_speed)             -- finishes tick 2, starts tick 3
    assert(same(scene:_display_matrix(), POST), "after the slide the matrix is post-op")
    print("PASS: update() loop shows pre-op during the slide")
end

-- The puzzle's displayed matrix at the start of every slide equals the recap's frame matrix.
do
    local scene = new_scene()
    scene:start_run()
    local shown = {}
    for _ = 1, 600 do
        if not scene.running then break end
        scene:do_step()
        if scene.anim_t == 0 then
            shown[#shown + 1] = scene:_display_matrix():copy()
        end
    end
    assert(scene.status == "win", "precondition: run wins")
    local frames = scene._run_frames
    assert(#frames == #shown, "one recorded frame per slide")
    for i, f in ipairs(frames) do
        assert(shown[i]:equals(f.matrix), "slide " .. i .. " shows the same matrix as the recap")
    end
    print("PASS: puzzle slides match recap frames")
end

-- Reset and a fresh run drop any stale display matrix.
do
    local scene = new_scene()
    scene:start_run()
    scene:do_step(); scene:do_step()
    assert(scene._anim_display_matrix ~= nil, "precondition: display matrix is set mid-run")
    scene:do_reset()
    assert(scene._anim_display_matrix == nil, "reset clears the display matrix")
    scene:start_run()
    assert(scene._anim_display_matrix == nil, "start_run clears the display matrix")
    scene:load_puzzle(S.puzzle("flip"))
    assert(scene._anim_display_matrix == nil, "load_puzzle clears the display matrix")
    print("PASS: display matrix cleared on reset/start/load")
end
