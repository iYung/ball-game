-- Two-source runs in the puzzle scene: loading both sources, per-matrix op
-- firing, two-cell tiles, merging, every failure banner, the sink, drawing
-- queries and the recorded recap frames.

local runner      = require("lua/headless/runner")
local Stubs       = require("lua/headless/stubs")
local Matrix      = require("lua/game/matrix_math")
local MatrixScene = require("lua/game/scenes/matrix_scene")
local Timeline    = require("lua/game/timeline")

local CS, GX, GY = MatrixScene.GEOM.CELL_SIZE, MatrixScene.GEOM.GRID_X, MatrixScene.GEOM.GRID_Y

local function px(x, y) return GX + (x - 1) * CS, GY + (y - 1) * CS end

local function input(rows)
    return { rows = #rows, cols = #rows[1], values = rows }
end

local function op(name, x, y, params)
    return { kind = "op", op = name, x = x, y = y, params = params }
end
local function pusher(id, x, y) return { kind = "pusher", id = id, x = x, y = y } end
local function at(x, y) return { x = x, y = y } end

-- o: a, b (input rows; b optional), at_a, at_b, sink, target, locked, gaps
local function new_scene(o)
    local def = {
        name = "pair", grid_w = 10, grid_h = 10,
        source = o.at_a, input = input(o.a),
        sink = o.sink or at(10, 10), target = input(o.target or { { 0 } }),
        locked = o.locked or {}, gaps = o.gaps,
    }
    if o.b then def.source2, def.input2 = o.at_b, input(o.b) end
    local ctx = runner.setup(function(_, sm) return MatrixScene.new_from_def(def, sm) end)
    return ctx.sm.current
end

-- commands: { { tick, pusher, cmd }, ... }, at most one lane per entry of a tick
local function program(scene, commands)
    local lane = {}
    for _, c in ipairs(commands) do
        lane[c[1]] = (lane[c[1]] or 0) + 1
        Timeline.set(scene.timeline, lane[c[1]], c[1], c[2], c[3])
    end
end

local function step(scene, n)
    for _ = 1, n or 1 do
        assert(scene.running, "run ended early: " .. tostring(scene.status))
        scene:do_step()
    end
end

local function settle(scene) scene.anim_t = 1 end

local function same(m, rows)
    return m ~= nil and m:equals(Matrix.new(#rows, #rows[1], rows))
end

local function drawn(scene)
    Stubs.clear_text()
    scene:draw()
    local seen = {}
    for _, t in ipairs(Stubs.drawn_text()) do seen[t] = (seen[t] or 0) + 1 end
    return seen
end

local function expect_shown(scene, expected, label)
    local got = scene:ui_matrices()
    assert(#got == #expected, label .. ": matrix count " .. #got)
    for i, want in ipairs(expected) do
        assert(got[i].x == want[1] and got[i].y == want[2],
            label .. ": matrix " .. i .. " at " .. got[i].x .. "," .. got[i].y)
        assert(same(Matrix.new(#got[i].values, #got[i].values[1], got[i].values), want[3]),
            label .. ": matrix " .. i .. " values")
    end
end

local function expect_end(scene, status, banner)
    assert(not scene.running, "run should have ended")
    assert(scene.status == status, "status " .. tostring(scene.status) .. ", expected " .. status)
    assert(drawn(scene)[banner], "banner not drawn: " .. banner)
end

-- ── Loading ──────────────────────────────────────────────────────────────────
do
    local scene = new_scene({
        a = { { 1, 2 } }, at_a = at(2, 2), b = { { 3 }, { 4 } }, at_b = at(7, 2),
        locked = { op("matrix_add", 5, 6, { facing = "left" }), op("matrix_mul", 8, 8),
                   op("matrix_add", 3, 2),            -- on source 1: skipped
                   op("matrix_mul", 10, 5),           -- partner off the grid: skipped
                   op("scalar_add", 1, 9) },
    })
    assert(same(scene.input2_matrix, { { 3 }, { 4 } }), "input2 built")
    assert(scene:ui_tile(2, 2).index == 1 and scene:ui_tile(3, 2).index == 1, "source 1 index")
    assert(scene:ui_tile(7, 3).index == 2 and scene:ui_tile(7, 3).kind == "source", "source 2 index")
    local left = scene:ui_tile(4, 6)
    assert(left.op == "matrix_add" and left.facing == "left", "ref cell reports the tile")
    assert(scene:ui_tile(9, 8).facing == "right", "missing facing defaults to right")
    assert(scene.grid:get(5, 6).locked, "locked")
    assert(scene:ui_tile(10, 5) == nil and scene:ui_tile(4, 2) == nil, "bad entries skipped")
    assert(scene:ui_tile(1, 9).op == "scalar_add", "single-cell locked tile kept")
    expect_shown(scene, { { 2, 2, { { 1, 2 } } }, { 7, 2, { { 3 }, { 4 } } } }, "idle")
    assert(scene:ui_matrix()[1][2] == 2, "ui_matrix is the primary")
    local seen = drawn(scene)
    assert(seen["SRC 1"] and seen["SRC 2"] and seen["INPUT 1"] and seen["INPUT 2"], "two-source labels")

    local single = new_scene({ a = { { 1 } }, at_a = at(2, 2) })
    assert(single.input2_matrix == nil and single:ui_tile(2, 2).index == nil, "single source")
    seen = drawn(single)
    assert(seen["SRC"] and seen["INPUT"] and not seen["SRC 1"], "single-source labels")
    expect_shown(single, { { 2, 2, { { 1 } } } }, "single idle")
    assert(MatrixScene.GEOM.MATRIX_BORDER[1][1] == 0.91 and MatrixScene.GEOM.MATRIX_BORDER[2][3] == 0.90,
        "border colours")
    print("PASS: two-source loading")
end

-- ── Merge, queries and frames ────────────────────────────────────────────────
-- 1x1 A moves right onto L (4,2), B moves left onto R (5,2).
local function simple(o)
    o = o or {}
    local width_b = o.b and #o.b[1] or 1
    local locked = { pusher(1, 2, 2), pusher(2, 6 + width_b, 2), op(o.op or "matrix_add", 4, 2) }
    for _, t in ipairs(o.extra or {}) do locked[#locked + 1] = t end
    local scene = new_scene({
        a = o.a or { { 2 } }, at_a = at(3, 2), b = o.b or { { 5 } }, at_b = at(6, 2),
        locked = locked, sink = o.sink, target = o.target, gaps = o.gaps,
    })
    program(scene, o.commands or { { 1, 1, "right" }, { 1, 2, "left" }, { 2, 1, "stop" } })
    return scene
end

do
    local scene = simple({ sink = at(10, 2),
        commands = { { 1, 1, "right" }, { 1, 2, "left" }, { 2, 2, "stop" } } })
    scene:start_run()
    expect_shown(scene, { { 3, 2, { { 2 } } }, { 6, 2, { { 5 } } } }, "start")
    step(scene)   -- A reaches L, B reaches R: merge
    assert(scene.sim.second == nil and scene.second_matrix == nil, "merged state")
    assert(same(scene.current_matrix, { { 7 } }) and scene.sim.x == 4, "result at L")
    assert(scene.disarmed["4,2"], "own tile disarmed")
    expect_shown(scene, { { 4, 2, { { 2 } } }, { 5, 2, { { 5 } } } }, "sliding in")
    assert(scene:ui_matrix()[1][1] == 2, "primary pre-op")
    scene.anim_t = 0.5
    local seen = drawn(scene)
    assert(seen["2"] and seen["5"], "both drawn mid-slide")
    settle(scene)
    expect_shown(scene, { { 4, 2, { { 7 } } } }, "settled")
    assert(drawn(scene)["7"], "result drawn")

    local f = scene._run_frames[1]
    assert(f.tag == 1 and same(f.matrix, { { 2 } }), "primary frame")
    assert(f.to_x == px(4, 2) and f.from_x == px(3, 2), "primary path")
    assert(f.second.tag == 2 and same(f.second.matrix, { { 5 } }), "second frame")
    assert(f.second.from_x == px(6, 2) and f.second.to_x == px(5, 2), "second path")
    assert(f.second.from_y == select(2, px(6, 2)), "second y")
    assert(f.merged.x == px(4, 2) and f.merged.tag == 1 and same(f.merged.matrix, { { 7 } }), "merged")

    step(scene)
    local g = scene._run_frames[2]
    assert(g.second == nil and g.merged == nil and g.tag == 1, "frame after the merge")
    expect_shown(scene, { { 5, 2, { { 7 } } } }, "result travels on")
    print("PASS: merge, queries and frames")
end

-- The merge into the second matrix's position: L is on the right.
do
    local scene = new_scene({
        a = { { 2 } }, at_a = at(6, 2), b = { { 3 } }, at_b = at(3, 2),
        locked = { pusher(1, 7, 2), pusher(2, 2, 2), op("matrix_mul", 4, 2) },
        sink = at(10, 10),
    })
    program(scene, { { 1, 1, "left" }, { 1, 2, "right" } })
    scene:start_run()
    step(scene)
    assert(scene._tag == 2 and scene.sim.x == 4 and same(scene.current_matrix, { { 6 } }),
        "result takes the left operand's place and colour")
    local f = scene._run_frames[1]
    assert(f.tag == 1 and f.to_x == px(5, 2) and same(f.matrix, { { 2 } }),
        "primary frame is source 1's own motion")
    assert(f.merged.x == px(4, 2) and f.merged.tag == 2, "merged at L")
    expect_shown(scene, { { 5, 2, { { 2 } } }, { 4, 2, { { 3 } } } }, "sliding in")
    settle(scene)
    expect_shown(scene, { { 4, 2, { { 6 } } } }, "settled at L")
    local body = scene:_shown_matrices()[1]
    assert(body.px == px(4, 2) and body.tag == 2, "drawn at L in colour 2")
    program(scene, { { 2, 1, "stop" } })
    step(scene)
    assert(scene._run_frames[2].tag == 2, "later frames keep the colour")
    print("PASS: merge at the second matrix")
end

-- A waiting matrix just sits there; arrival order does not matter.
for _, first in ipairs({ 1, 2 }) do
    local second = 3 - first
    local dir = { "right", "left" }
    local scene = simple({ commands = {
        { 1, first, dir[first] }, { 2, first, "stop" }, { 4, second, dir[second] } } })
    scene:start_run()
    step(scene, 3)
    assert(scene.sim.second and scene.status == "running", "one covered input waits")
    settle(scene)
    drawn(scene)
    step(scene)
    assert(scene.sim.second == nil and same(scene.current_matrix, { { 7 } }), "merged on arrival")
end
print("PASS: waiting and arrival order")

-- ── Single-cell ops with two matrices ────────────────────────────────────────
do
    -- Both pass over the same +1 tile; each fires it once.
    local scene = new_scene({
        a = { { 1 } }, at_a = at(3, 5), b = { { 10 } }, at_b = at(5, 9),
        locked = { pusher(1, 2, 5), pusher(2, 5, 10), op("scalar_add", 5, 5) },
    })
    program(scene, { { 1, 1, "right" }, { 4, 1, "left" }, { 4, 2, "up" }, { 8, 2, "stop" },
                     { 5, 1, "stop" } })
    scene:start_run()
    step(scene, 2)
    assert(same(scene.current_matrix, { { 2 } }) and same(scene.second_matrix, { { 10 } }), "A fired")
    step(scene, 5)
    assert(same(scene.second_matrix, { { 11 } }), "B fires the same tile")
    assert(scene.second_fired["5,5"] and not scene.occupied_ops["5,5"], "per-matrix state")
    step(scene)
    assert(same(scene.second_matrix, { { 11 } }), "no refire while B stays on it")
    print("PASS: per-matrix firing")
end

-- An op that leaves a matrix blocked ends the run; the other one's op never fires.
do
    local scene = new_scene({
        a = { { 1, 2 } }, at_a = at(2, 5), b = { { 9 } }, at_b = at(8, 8),
        locked = { pusher(1, 1, 5), op("transpose", 4, 5), op("scalar_add", 8, 7),
                   pusher(2, 8, 9) },
        gaps = { { x = 3, y = 6 } },
    })
    program(scene, { { 1, 1, "right" }, { 1, 2, "up" } })
    scene:start_run()
    step(scene)
    assert(same(scene.second_matrix, { { 9 } }), "source 2 not evaluated after the failure")
    expect_end(scene, "blocked", "FAIL — matrix is blocked")
    settle(scene)
    expect_shown(scene, { { 3, 5, { { 1 }, { 2 } } }, { 8, 7, { { 9 } } } }, "both stay visible")
    print("PASS: op blocks a matrix")
end

-- An op that turns one matrix into the other: collided (from either slot).
for _, slot in ipairs({ 1, 2 }) do
    local turning, still = { { 1, 2 } }, { { 9 } }
    local o = { locked = { pusher(1, 1, 5), op("transpose", 4, 5) } }
    if slot == 1 then
        o.a, o.at_a, o.b, o.at_b = turning, at(2, 5), still, at(3, 6)
    else
        o.a, o.at_a, o.b, o.at_b = still, at(3, 6), turning, at(2, 5)
    end
    local scene = new_scene(o)
    program(scene, { { 1, 1, "right" } })
    scene:start_run()
    step(scene)
    expect_end(scene, "collided", "FAIL — matrices collided")
end
print("PASS: op collides the matrices")

-- ── Start of the run ─────────────────────────────────────────────────────────
do
    -- Sources never sit on tiles in a puzzle file; build that board directly.
    local scene = new_scene({ a = { { 2 } }, at_a = at(5, 2), b = { { 3 } }, at_b = at(4, 2),
                              locked = { pusher(1, 1, 9) } })
    scene.grid.cells[2][4], scene.grid.cells[2][5] = nil, nil
    scene.grid:put(4, 2, { kind = "op", op = "matrix_add", params = { facing = "right" } })
    scene:start_run()
    assert(scene.running and scene.sim.second == nil and same(scene.current_matrix, { { 5 } }),
        "two-cell tile under the sources merges at the start")
    assert(scene.sim.x == 4 and scene._tag == 2 and scene.anim_to_x == px(4, 2), "at L")
    assert(#scene._run_frames == 0, "no frame at the start")
    expect_shown(scene, { { 4, 2, { { 5 } } } }, "start merge")

    local over = new_scene({ a = { { 1, 1 } }, at_a = at(2, 2), b = { { 2 } }, at_b = at(3, 2),
                             locked = { pusher(1, 1, 9) } })
    over:start_run()
    expect_end(over, "collided", "FAIL — matrices collided")
    over:do_reset()
    assert(over.status == nil and over.second_matrix == nil, "reset")
    expect_shown(over, { { 2, 2, { { 1, 1 } } }, { 3, 2, { { 2 } } } }, "previews back")
    print("PASS: start-of-run evaluation")
end

-- ── Movement failures leave everything where it was ──────────────────────────
do
    local scene = simple({ commands = { { 1, 1, "right" }, { 1, 2, "left" } } })
    scene:start_run()
    step(scene, 2)   -- merge, then the two pushers squeeze the result
    assert(scene.status == "blocked", "opposing pushers")

    local head = new_scene({ a = { { 1 } }, at_a = at(3, 2), b = { { 2 } }, at_b = at(4, 2),
                             locked = { pusher(1, 2, 2), pusher(2, 5, 2) } })
    program(head, { { 1, 1, "right" }, { 1, 2, "left" } })
    head:start_run()
    step(head)
    expect_end(head, "collided", "FAIL — matrices collided")
    expect_shown(head, { { 3, 2, { { 1 } } }, { 4, 2, { { 2 } } } }, "unmoved")
    assert(head.sim.tick == 0 and #head._run_frames == 0, "tick not committed")

    local wall = new_scene({ a = { { 1 } }, at_a = at(2, 2), b = { { 2 } }, at_b = at(10, 5),
                             locked = { pusher(1, 9, 5) } })
    program(wall, { { 1, 1, "right" } })
    wall:start_run()
    step(wall)
    expect_end(wall, "blocked", "FAIL — matrix is blocked")
    print("PASS: movement failures")
end

-- ── Two-cell failures ────────────────────────────────────────────────────────
do
    local scene = simple({ b = { { 1, 2 } } })
    scene:start_run()
    step(scene)
    expect_end(scene, "bad_shape", "FAIL — can't add 1x1 and 1x2")
    settle(scene)
    expect_shown(scene, { { 4, 2, { { 2 } } }, { 5, 2, { { 1, 2 } } } }, "both stay")
    assert(scene._run_frames[1].second and not scene._run_frames[1].merged, "no merge frame")
    scene:do_reset()
    assert(scene.status_message == nil, "reset clears the message")

    -- A stale message must not replace a later banner.
    scene:start_run()
    step(scene)
    scene.grid.cells[2][2], scene.grid.cells[2][8] = nil, nil
    scene:key_pressed("r")
    assert(scene.status == "no_pusher" and drawn(scene)["Place a pusher first"], "no_pusher banner")

    local mul = simple({ op = "matrix_mul", a = { { 1 }, { 1 } }, b = { { 1 }, { 1 } } })
    mul:start_run()
    step(mul)
    expect_end(mul, "bad_shape", "FAIL — can't multiply 2x1 by 2x1")

    for _, b in ipairs({ { { 9 } }, false }) do
        -- One matrix on both inputs, with and without a second matrix.
        local both = new_scene({
            a = { { 1, 2 } }, at_a = at(2, 2), b = b or nil, at_b = at(9, 9),
            locked = { pusher(1, 1, 2), op("matrix_add", 4, 2) },
        })
        program(both, { { 1, 1, "right" } })
        both:start_run()
        step(both)
        assert(both.status == "running", "one input covered: waits")
        step(both)
        expect_end(both, "both_inputs", "FAIL — one matrix on both inputs")
    end
    print("PASS: two-cell failures")
end

-- ── Merge that does not fit, fired tiles and disarming ───────────────────────
-- A (2x1) is the left operand, B (1x2) the right: the product is 2x2 at L (4,4).
local function product(o)
    local locked = { pusher(1, 2, 4), pusher(2, 9, 4), op("matrix_mul", 4, 4) }
    for _, t in ipairs(o.extra or {}) do locked[#locked + 1] = t end
    local scene = new_scene({
        a = { { 1 }, { 2 } }, at_a = at(3, 4), b = { { 3, 4 } }, at_b = at(7, 4),
        locked = locked, gaps = o.gaps, sink = o.sink, target = o.target,
    })
    program(scene, { { 1, 1, "right" }, { 1, 2, "left" }, { 2, 1, "stop" },
                     { 3, 2, "stop" }, { 5, 2, "stop" } })
    return scene
end

do
    local scene = product({ gaps = { { x = 5, y = 5 } } })
    scene:start_run()
    step(scene, 2)
    expect_end(scene, "blocked", "FAIL — matrix is blocked")
    assert(scene.sim.second and same(scene.current_matrix, { { 1 }, { 2 } })
        and same(scene.second_matrix, { { 3, 4 } }), "both uncommitted")
    assert(not scene._run_frames[2].merged, "no merged frame")

    scene = product({ extra = { op("scalar_add", 4, 5), op("scalar_add", 5, 5) } })
    scene:start_run()
    step(scene, 2)
    assert(scene.sim.second == nil, "merged")
    -- A fired (4,5) on the way in (+1); (5,5) is only newly covered by the product.
    assert(same(scene.current_matrix, { { 6, 8 }, { 9, 12 } }), "product of the changed A")
    assert(scene.occupied_ops["4,5"] and not scene.occupied_ops["5,5"], "fired set is left's")
    step(scene)
    assert(same(scene.current_matrix, { { 6, 8 }, { 9, 12 } }), "nothing refires while covered")
    print("PASS: merge fit and fired tiles")
end

do
    -- The 1x3 product spills onto its own tile's second cell and survives.
    local scene = new_scene({
        a = { { 2 } }, at_a = at(3, 4), b = { { 1, 2, 3 } }, at_b = at(6, 4),
        locked = { pusher(1, 2, 4), pusher(2, 9, 4), op("matrix_mul", 4, 4),
                   pusher(3, 5, 2), pusher(4, 6, 7) },
    })
    program(scene, { { 1, 1, "right" }, { 1, 2, "left" }, { 2, 1, "stop" }, { 2, 2, "stop" },
                     { 2, 3, "down" }, { 3, 4, "up" }, { 4, 3, "up" } })
    scene:start_run()
    step(scene, 2)
    assert(scene.status == "running" and scene.disarmed["4,4"], "disarmed tile ignored")
    step(scene)   -- pushed down, off both cells: re-armed
    assert(scene.sim.y == 5 and not scene.disarmed["4,4"], "re-armed")
    step(scene)   -- pushed back up onto both cells
    expect_end(scene, "both_inputs", "FAIL — one matrix on both inputs")
    print("PASS: disarm and re-arm after a merge")
end

-- ── Sink ─────────────────────────────────────────────────────────────────────
do
    for _, sink in ipairs({ at(4, 2), at(5, 2) }) do
        -- Either matrix reaching the sink with two left fails, even if it matches.
        local scene = new_scene({
            a = { { 2 } }, at_a = at(3, 2), b = { { 2 } }, at_b = at(6, 2), target = { { 2 } },
            sink = sink, locked = { pusher(1, 2, 2), pusher(2, 7, 2) },
        })
        program(scene, { { 1, 1, "right" }, { 1, 2, "left" } })
        scene:start_run()
        step(scene)
        expect_end(scene, "uncombined", "FAIL — matrices not combined")
    end
    -- A merge on the tick that touches the sink is judged on the result: only the
    -- 2x2 product reaches (5,5).
    for status, target in pairs({ win = { { 3, 4 }, { 6, 8 } }, fail = { { 0 } } }) do
        local scene = product({ sink = at(5, 5), target = target })
        scene:start_run()
        step(scene, 2)
        expect_end(scene, status, status == "win" and "WIN!" or "FAIL — matrix mismatch")
        assert(scene._run_frames[2].merged, "final tick is the merge")
    end
    print("PASS: sink cases")
end

do
    -- Single source: an op failure is not overwritten by the sink.
    local scene = new_scene({
        a = { { 1 }, { 2 } }, at_a = at(2, 5), sink = at(3, 6), target = { { 1, 2 } },
        locked = { pusher(1, 1, 5), op("transpose", 3, 5) }, gaps = { { x = 4, y = 5 } },
    })
    program(scene, { { 1, 1, "right" } })
    scene:start_run()
    step(scene)
    expect_end(scene, "blocked", "FAIL — matrix is blocked")
    assert(scene.anim_t == 0 and #scene._run_frames == 1, "the step still slides in")
    print("PASS: blocked is final")
end

do
    local scene = simple({ commands = { { 1, 1, "stop" } } })
    scene:start_run()
    step(scene, 2)
    assert(scene.status == "stuck" and scene.anim_t == 1, "stuck with two matrices")
    expect_shown(scene, { { 3, 2, { { 2 } } }, { 6, 2, { { 5 } } } }, "stuck")
    scene:load_puzzle(1)
    assert(scene.second_matrix == nil and scene.sim == nil, "load clears the run")
    print("PASS: stuck and reload")
end

print("ALL TWO-SOURCE RUN TESTS PASSED")
