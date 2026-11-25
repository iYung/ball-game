-- Regression: simultaneous pusher moves (docs/design/pusher-simultaneous-moves.md)

local S = require("tests/support/shipped")
local Sim    = require("lua/game/pusher_sim")
local runner = require("lua/headless/runner")

local function state(x, y, pushers)
    return { x = x, y = y, rows = 2, cols = 2, w = 10, h = 10, tick = 0, pushers = pushers }
end

-- Bug 2: a pusher right next to the matrix steps out of the way in the same tick the matrix
-- is shoved into its cell. Valid: nothing collides.
do
    local s = state(8, 3, { { id = "A", x = 7, y = 3, dir = "left" },
                            { id = "B", x = 10, y = 4, dir = "left" } })
    local moved, blocked = Sim.advance(s)
    assert(moved and not blocked, "leading pusher moving away must not block the push")
    assert(s.x == 7 and s.pushers[1].x == 6 and s.pushers[2].x == 9, "matrix, A and B all moved left")
    print("PASS: pusher steps out of the way as the matrix arrives")
end

-- Same, vertical.
do
    local s = state(3, 8, { { id = "A", x = 3, y = 7, dir = "up" },
                            { id = "B", x = 4, y = 10, dir = "up" } })
    local moved, blocked = Sim.advance(s)
    assert(moved and not blocked and s.y == 7 and s.pushers[1].y == 6, "vertical lead pusher")
    print("PASS: leading pusher vertical")
end

-- A pusher that stays put (or is blocked) inside the arriving footprint is still a collision.
do
    local s = state(8, 3, { { id = "A", x = 7, y = 3, dir = "stop" },
                            { id = "B", x = 10, y = 4, dir = "left" } })
    local _, blocked = Sim.advance(s)
    assert(blocked, "stationary pusher in the way is a collision")
    print("PASS: stationary pusher still collides")
end

-- Bug 1: a blocked push is rolled back completely, so no pusher ends up under the matrix.
do
    local s = state(7, 3, { { id = "A", x = 5, y = 3, dir = "right" },
                            { id = "B", x = 9, y = 4, dir = "left" } })
    local moved, blocked = Sim.advance(s)
    assert(blocked and not moved, "A steps into the cell the matrix lands on: blocked")
    assert(s.x == 7 and s.y == 3, "matrix unmoved")
    assert(s.pushers[1].x == 5 and s.pushers[2].x == 9 and s.pushers[2].y == 4,
        "B did not slide under the matrix")
    print("PASS: blocked push rolls back contact pushers")
end

-- Scene level: after a blocked run no pusher sits inside the matrix footprint.
do
    local ctx   = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(S.puzzle("identity")) end)
    local scene = ctx.sm.current
    local function add(x, y, cmds)
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
    end
    add(1, 5, { [1] = "right" })   -- behind the matrix (2..3, 5..6), pushes it
    add(4, 6, { [1] = "right" })   -- leads it, moving away as it is pushed
    scene:start_run()
    scene:do_step()
    assert(scene.status ~= "blocked", "pushing with a pusher leading the way is valid")
    assert(scene.sim.x == 3, "matrix advanced one cell")
    print("PASS: scene — lead pusher plus push pusher")
end
print("ALL PUSHER SIMULTANEOUS TESTS PASSED")
