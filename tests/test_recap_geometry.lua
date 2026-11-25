-- The solution recap must draw the board with the same geometry the game scene
-- recorded its run frames in; otherwise the replayed pusher/matrix are offset
-- from the grid.

local S = require("tests/support/shipped")
local runner = require("lua/headless/runner")
local Timeline = require("lua/game/timeline")
local Recap = require("lua/game/scenes/solution_recap_scene")

local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(S.puzzle("identity")) end)
local scene = ctx.sm.current
scene:_place_tile_at(1, 6, { kind = "pusher" })
Timeline.set(scene.timeline, 1, 1, scene.grid:get(1, 6).id, "right")
scene:start_run()
for _ = 1, 600 do
    if not scene.running then break end
    scene:do_step()
end
assert(scene.status == "win", "precondition: run wins")

local f = scene._run_frames[1]
local rx, ry = Recap.cell_top_left(1, 6)
assert(f.pushers_from[1].px == rx and f.pushers_from[1].py == ry,
    string.format("recap grid cell (1,6) at %d,%d but run frame pusher at %d,%d",
        rx, ry, f.pushers_from[1].px, f.pushers_from[1].py))
local sx, sy = Recap.cell_top_left(scene.puzzle.source.x, scene.puzzle.source.y)
assert(f.from_x == sx and f.from_y == sy, "matrix start frame lines up with the recap source cell")
print("PASS: recap geometry matches run frames")
