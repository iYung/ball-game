local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
    return ctx.sm.current
end

-- Place a pusher and program its commands (cmds = { [tick] = "right", ... }). Commands
-- persist, so one entry is enough to keep a pusher moving. Written straight into the shared
-- timeline shape scene.timeline[lane][tick] = { pusher = id, cmd = cmd } (first free lane).
local function add_pusher(scene, x, y, cmds)
    scene:_place_tile_at(x, y, { kind = "pusher" })
    local id = scene.grid:get(x, y).id
    for tick, cmd in pairs(cmds) do
        for lane = 1, 4 do
            if scene.timeline[lane][tick] == nil then
                scene.timeline[lane][tick] = { pusher = id, cmd = cmd }
                break
            end
        end
    end
    return id
end

local function run_to_end(scene)
    scene:start_run()
    for _ = 1, 600 do
        if not scene.running then break end
        scene:do_step()
    end
end

-- NOTE (puzzle-scene-ui-overhaul Task 2): commands persist now, so "right" x8 became one
-- "right" at tick 1; same physics (pusher keeps walking until the matrix is at the sink).
-- Puzzle 1: 2x2 identity from source (2,5) to sink (10,5). A pusher starts just left
-- of the source and pushes the matrix right until it hits the sink.
local function carry(scene)
    add_pusher(scene, 1, 6, { [1] = "right" })
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
    scene:_place_tile_at(5, 5, { kind = "op", op = "scalar_mul", params = { scalar = -1 } })
    run_to_end(scene)
    assert(scene.status == "fail", "x-1 makes identity mismatch, got " .. tostring(scene.status))
    assert(scene.current_matrix.values[1][1] == -1, "x-1 fired exactly once")
    print("PASS: op fires once on path")
end

-- No pushers: matrix never moves and the run reports stuck as soon as a tick moves nothing (no commands pending).
do
    local scene = new_scene()
    run_to_end(scene)
    assert(scene.status == "stuck", "idle run is stuck, got " .. tostring(scene.status))
    assert(scene.sim.tick == 1, "stuck on the first tick: no commands and nothing moved")
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

-- Timeline clicks: an armed chip writes the selected pusher's command into a slot,
-- right-click clears it, the scroll arrows page the window; all ignored mid-run.
-- (Rewritten: old slot cycling and the +/- length buttons were removed by the timeline overhaul.)
do
    local Timeline = require("lua/game/timeline")
    local UI = require("lua/core/ui")
    local scene = new_scene()
    local id = add_pusher(scene, 1, 6, {})
    scene:draw()
    local function click_id(eid, btn)
        local e = UI.find(scene:ui_elements(), eid)
        local x, y = UI.centre(e.rect)
        scene:mouse_pressed(x, y, btn or 1)
        scene:mouse_released(x, y, btn or 1)
    end
    click_id("chip:up")
    click_id("slot:1:1")
    local c = Timeline.get(scene.timeline, 1, 1)
    assert(c and c.cmd == "up" and c.pusher == id, "armed chip written to the slot")
    click_id("slot:1:1", 2)
    assert(Timeline.get(scene.timeline, 1, 1) == nil, "right-click clears")
    click_id("tl:scroll_right")
    assert(scene.timeline_scroll > 0, "scroll arrow pages the window")
    scene.timeline_scroll = 0
    scene.running = true
    local e = UI.find(scene:ui_elements(), "slot:1:1")
    scene:mouse_pressed(e.rect.x + 1, e.rect.y + 1, 1)
    assert(Timeline.get(scene.timeline, 1, 1) == nil, "timeline locked while running")
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
    assert(l["P"] and l["[X]"] and l["T"] and l["xk"], "puzzle 1 offers all ops")
    scene:load_puzzle(2)
    l = labels(scene)
    assert(l["T"] and not l["xk"] and not l["+k^"], "puzzle 2 offers only transpose")
    scene.palette:select({ kind = "op", op = "transpose" })
    scene:load_puzzle(4)
    assert(scene.palette:selected() == nil, "selection of a now-hidden op is cleared")
    assert(labels(scene)["FLv"], "puzzle 4 offers flip vertical")
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
    add_pusher(scene, 1, 6, { [1] = "right" })
    scene:key_pressed("r")
    assert(scene.status == "running" or scene.sim ~= nil, "run starts once a pusher is placed")
    print("PASS: no_pusher guard")
end

-- A pusher that walks into the grid wall is a blocked move → "blocked" status.
do
    local scene = new_scene()
    add_pusher(scene, 1, 6, { [1] = "left" })
    run_to_end(scene)
    assert(scene.status == "blocked", "blocked pusher (wall) gives blocked status, got " .. tostring(scene.status))
    print("PASS: blocked pusher wall gives blocked status")
end

-- A pusher that tries to shove the matrix off the grid is a blocked move → "blocked" status.
-- Push the 2x2 matrix from (2,5) down 5 times; on tick 5 the matrix is at (2,9) and
-- shoving it to (2,10) would put row 11 off the grid.
do
    local scene = new_scene()
    add_pusher(scene, 2, 4, { [1] = "down" })
    run_to_end(scene)
    assert(scene.status == "blocked", "blocked pusher (matrix at wall) gives blocked status, got " .. tostring(scene.status))
    print("PASS: blocked pusher matrix-at-wall gives blocked status")
end

-- Fixed player-placed tile has fixed=true and param edits are blocked.
do
    local scene = new_scene()
    -- Place an edge_scale tile with fixed=true directly.
    scene:_place_tile_at(5, 5, { kind="op", op="edge_scale", fixed=true })
    local tile = scene.grid:get(5, 5)
    assert(tile ~= nil, "fixed edge_scale placed")
    assert(tile.fixed == true, "tile.fixed is true, got " .. tostring(tile.fixed))
    assert(tile.params.scalar == 2 and tile.params.edge == "top", "default params")

    -- A tool other than the eraser: no third of the cell may edit or replace the tile.
    -- GRID_X=130, GRID_Y=10, CELL_SIZE=52: cell (5,5) starts at (338, 218).
    scene.palette:select({ kind = "op", op = "transpose" })
    for _, dx in ipairs({ 5, 26, 47 }) do
        scene:mouse_pressed(338 + dx, 244, 1)
        assert(scene.grid:get(5, 5) == tile, "fixed tile not replaced")
        assert(tile.params.scalar == 2 and tile.params.edge == "top",
            "fixed tile unchanged after click at " .. dx .. ", got "
            .. tostring(tile.params.scalar) .. " " .. tostring(tile.params.edge))
    end
    print("PASS: fixed player-placed tile blocks param edits")
end

-- Puzzle-placed locked op loads correctly (P21: the arch gap row at y=4 sits right below it).
do
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(21) end)
    local scene = ctx.sm.current

    -- Anchor at (5,3)
    local anchor = scene.grid:get(5, 3)
    assert(anchor ~= nil, "locked edge_scale anchor present at (5,3)")
    assert(anchor.kind == "op",    "anchor kind=op, got " .. tostring(anchor.kind))
    assert(anchor.op   == "edge_scale", "anchor op=edge_scale, got " .. tostring(anchor.op))
    assert(anchor.locked == true,  "anchor is locked")
    assert(anchor.params.scalar == 3, "anchor scalar=3, got " .. tostring(anchor.params.scalar))
    assert(anchor.params.edge == "top", "anchor edge=top, got " .. tostring(anchor.params.edge))

    -- Only the anchor cell is used, no ref cells below.
    local ok4 = scene.grid:is_ref(5, 4)
    assert(not ok4, "(5,4) is not a ref cell")

    -- Row above the tile should also be empty.
    local ok2 = scene.grid:is_ref(5, 2)
    assert(not ok2, "row above tile (5,2) is not a ref")

    print("PASS: locked single-cell op loads correctly")
end

-- Puzzle-placed locked op fires with correct params in simulation.
do
    local Sim = require("lua/game/pusher_sim")
    local Matrix = require("lua/game/matrix_math")
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(21) end)
    local scene = ctx.sm.current

    local tile = scene.grid:get(5, 3)
    local inp  = Matrix.new(2, 2, {{1,2},{3,4}})
    local out  = Sim.apply_op(tile, inp)
    -- edge_scale(edge=top, scalar=3): row 1 → {3,6}; row 2 unchanged
    assert(out.values[1][1] == 3, "edge_scale row1 col1 = 3, got " .. tostring(out.values[1][1]))
    assert(out.values[1][2] == 6, "edge_scale row1 col2 = 6, got " .. tostring(out.values[1][2]))
    assert(out.values[2][1] == 3, "edge_scale row2 col1 unchanged = 3, got " .. tostring(out.values[2][1]))
    assert(out.values[2][2] == 4, "edge_scale row2 col2 unchanged = 4, got " .. tostring(out.values[2][2]))
    print("PASS: locked op fires with correct params")
end

-- Run ends once the commands run out. (Replaces the old "timeout" test: with persistent commands
-- and a 60-tick timeline every run ends in stuck/blocked/win/fail within a bounded number of
-- ticks, so the old 500-tick MAX_TICKS "timeout" status was unreachable and has been removed.)
-- A pusher away from the matrix oscillates, stops at tick 60, and the run is stuck at tick 61.
do
    local scene = new_scene()
    local cmds = {}
    for t = 1, 59 do cmds[t] = (t % 2 == 1) and "right" or "left" end
    cmds[60] = "stop"     -- an unstopped pusher would keep walking into the wall and end "blocked"
    add_pusher(scene, 5, 2, cmds)
    run_to_end(scene)
    assert(scene.status == "stuck", "run ends stuck after the last command, got " .. tostring(scene.status))
    assert(scene.sim.tick == 61, "stuck on the first tick after the last command, got " .. scene.sim.tick)
    print("PASS: run ends after the last command")
end

-- Two pushers in the same direction: forces aggregate, matrix moves only one cell.
-- Puzzle 1, 2×2 matrix at (2,5)–(3,6).
-- A at (1,5) right + B at (1,6) right: both step into the matrix's left column.
-- Net force = one right; matrix must end up at (3,5)–(4,6), not (4,5)–(5,6).
do
    local scene = new_scene()
    add_pusher(scene, 1, 5, { [1]="right" })   -- A
    add_pusher(scene, 1, 6, { [1]="right" })   -- B
    scene:start_run()
    scene:do_step()
    assert(scene.sim.x == 3 and scene.sim.y == 5,
        "two same-direction pushers move matrix one cell, got ("
        .. scene.sim.x .. "," .. scene.sim.y .. ")")
    print("PASS: same-direction pushers aggregate to one cell")
end

-- Two pushers in perpendicular directions: forces combine into a diagonal move.
-- Puzzle 1, 2×2 matrix at (2,5)–(3,6).
-- A at (1,5) right (steps into (2,5)) + B at (3,4) down (steps into (3,5)).
-- Net force = (+1,+1); matrix must move diagonally to (3,6)–(4,7).
-- An x-1 op at (4,6) (newly entered after the diagonal step) must fire.
do
    local scene = new_scene()
    add_pusher(scene, 1, 5, { [1]="right" })   -- A
    add_pusher(scene, 3, 4, { [1]="down"  })   -- B
    scene:_place_tile_at(4, 6, { kind = "op", op = "scalar_mul", params = { scalar = -1 } })
    scene:start_run()
    scene:do_step()
    assert(scene.sim.x == 3 and scene.sim.y == 6,
        "perpendicular pushers move matrix diagonally, got ("
        .. scene.sim.x .. "," .. scene.sim.y .. ")")
    assert(scene.current_matrix.values[1][1] == -1,
        "x-1 at (4,6) fires after diagonal move")
    print("PASS: perpendicular pushers combine into diagonal move")
end

-- Two pushers with opposing forces on the same axis → conflict → blocked status.
-- Puzzle 1, 2×2 matrix at (2,5)–(3,6).
-- A at (1,5) right + B at (4,5) left: both contact the matrix from opposite sides.
-- Net force is undefined (conflict); the run must give blocked status.
do
    local scene = new_scene()
    add_pusher(scene, 1, 5, { [1]="right" })   -- pushes from left
    add_pusher(scene, 4, 5, { [1]="left"  })   -- pushes from right
    scene:start_run()
    scene:do_step()
    assert(scene.status == "blocked",
        "opposing pushers on same axis must give blocked status, got " .. tostring(scene.status))
    print("PASS: opposing pushers conflict gives blocked status")
end

-- A pusher below the matrix going further down must not drag the matrix.
-- Puzzle 1: 2×2 matrix at (2,5)–(3,6). Pusher at (2,7) [one below the bottom],
-- going down — it is entirely outside and moving away. Matrix must stay put.
do
    local scene = new_scene()
    add_pusher(scene, 2, 7, { [1]="down" })
    scene:start_run()
    scene:do_step()
    assert(scene.sim.y == 5,
        "pusher below matrix going down must not drag it, got y=" .. scene.sim.y)
    print("PASS: pusher below matrix going down does not drag it")
end

-- Custom definitions for the fixed-preset and locked-entry checks below.
local function def_scene(extra)
    local def = {
        name = "custom", grid_w = 10, grid_h = 10,
        source = { x=2, y=5 }, sink = { x=10, y=5 }, gaps = {},
        input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
        target = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    }
    for k, v in pairs(extra) do def[k] = v end
    local ctx = runner.setup(function(_, sm)
        return require("lua/game/scenes/matrix_scene").new_from_def(def, sm)
    end)
    return ctx.sm.current, def
end

local function click_element(scene, eid)
    local UI = require("lua/core/ui")
    local e = UI.find(scene:ui_elements(), eid)
    assert(e, "element " .. eid .. " present")
    local x, y = UI.centre(e.rect)
    scene:mouse_pressed(x, y, 1)
    scene:mouse_released(x, y, 1)
    return e
end

local function drawn(scene)
    local Stubs = require("lua/headless/stubs")
    Stubs.clear_text()
    scene:draw()
    local out = {}
    for _, t in ipairs(Stubs.drawn_text()) do out[t] = true end
    return out
end

-- A fixed_ops table entry presets every tile placed from its button; the label shows it.
do
    local preset = { op = "scalar_mul", params = { scalar = -1 } }
    local scene = def_scene({ ops = {}, fixed_ops = { preset, "edge_add" } })
    assert(drawn(scene)["x-1!"], "preset label drawn")
    assert(click_element(scene, "palette:fixed:scalar_mul").label == "x-1!", "preset label")
    click_element(scene, "cell:5,2")
    local tile = scene.grid:get(5, 2)
    assert(tile.op == "scalar_mul" and tile.fixed == true, "fixed tile placed")
    assert(tile.params.scalar == -1, "preset applied, got " .. tostring(tile.params.scalar))
    assert(tile.params ~= preset.params, "placed params are a copy")
    click_element(scene, "cell:6,2")
    assert(scene.grid:get(6, 2).params ~= tile.params, "each tile has its own params")
    -- A string entry takes the defaults.
    assert(click_element(scene, "palette:fixed:edge_add").label == "+1^!", "default label")
    click_element(scene, "cell:7,2")
    local edge = scene.grid:get(7, 2)
    assert(edge.params.scalar == 1 and edge.params.edge == "top", "defaults for a string entry")
    print("PASS: fixed op presets")
end

-- Unsupported fixed_ops entries get no button.
do
    local scene = def_scene({ ops = {}, fixed_ops = { "negate", { op = "abs" }, {}, "flip_v" } })
    local fixed = {}
    for _, e in ipairs(scene:ui_elements()) do
        if e.id:sub(1, 14) == "palette:fixed:" then fixed[#fixed + 1] = e.id end
    end
    assert(#fixed == 1 and fixed[1] == "palette:fixed:flip_v", "only the supported entry, got " .. table.concat(fixed, ","))
    print("PASS: unsupported fixed op skipped")
end

-- Locked op entries are one cell whatever size fields they carry, with their own params.
do
    local entry = { kind="op", op="edge_scale", x=5, y=2, width=2, height=2, tile_rows=2, tile_cols=2,
                    params={ edge="left", scalar=-4 } }
    local scene, def = def_scene({ locked = { entry } })
    local tile = scene.grid:get(5, 2)
    assert(tile.locked and tile.width == nil and tile.height == nil, "locked tile is 1x1")
    assert(scene.grid:get(6, 2) == nil and scene.grid:get(5, 3) == nil, "no neighbouring cells taken")
    assert(not scene.grid:is_ref(6, 2) and not scene.grid:is_ref(5, 3), "no ref cells")
    assert(tile.params ~= def.locked[1].params, "locked params are a copy")
    local t = scene:ui_tile(5, 2)
    assert(t.kind == "op" and t.op == "edge_scale" and t.edge == "left" and t.scalar == -4 and t.dir == nil,
        "ui_tile fields")
    scene:_place_tile_at(6, 2, { kind="op", op="transpose" })
    local bare = scene:ui_tile(6, 2)
    assert(bare.op == "transpose" and bare.edge == nil and bare.scalar == nil, "no params, nil fields")
    print("PASS: locked entry placed 1x1, ui_tile fields")
end

-- The board drag ghost shows an op tile's operation and value.
do
    local scene = new_scene()
    scene._drag_tile  = { kind = "op", op = "scalar_sub", params = { scalar = 7 } }
    scene._drag_ghost = { cx = 5, cy = 1 }
    assert(drawn(scene)["-7"], "op ghost drawn with its value")
    print("PASS: op drag ghost text")
end

print("ALL TESTS PASSED")
