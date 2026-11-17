local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("game/scenes/matrix_scene").new(1) end)
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

-- Puzzle 1: 2x2 identity from (1,5) to sink (10,5). A pusher riding inside the matrix
-- walks right and carries it across.
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
    assert(p.x == 9 and p.y == 6, "pusher moved with the matrix, at " .. p.x .. "," .. p.y)
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

print("ALL TESTS PASSED")
