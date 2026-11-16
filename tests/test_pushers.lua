local Sim    = require("game/pusher_sim")
local Matrix = require("game/matrix_math")

-- slot() loops
do
    assert(Sim.slot(1, 4) == 1, "tick 1 -> slot 1")
    assert(Sim.slot(4, 4) == 4, "tick 4 -> slot 4")
    assert(Sim.slot(5, 4) == 1, "tick 5 wraps to slot 1")
    assert(Sim.slot(9, 4) == 1, "tick 9 wraps to slot 1")
    print("PASS: slot loops")
end

-- push only when the matrix covers the cell next to the pusher in its direction
do
    local p = { x = 3, y = 3, cmds = { "right" } }
    -- 2x2 matrix anchored (4,3): covers (4,3) -> adjacent right of pusher
    local dx, dy = Sim.net_push(4, 3, 2, 2, 10, 10, { p }, 1)
    assert(dx == 1 and dy == 0, "adjacent matrix is pushed right")
    -- matrix anchored (5,3) does not cover (4,3)
    dx, dy = Sim.net_push(5, 3, 2, 2, 10, 10, { p }, 1)
    assert(dx == 0 and dy == 0, "non-adjacent matrix is not pushed")
    -- idle / nil slot does nothing
    dx, dy = Sim.net_push(4, 3, 2, 2, 10, 10, { p }, 2)
    assert(dx == 0 and dy == 0, "nil command is idle")
    -- command pointing away from the matrix does nothing
    local q = { x = 3, y = 3, cmds = { "left" } }
    dx, dy = Sim.net_push(4, 3, 2, 2, 10, 10, { q }, 1)
    assert(dx == 0 and dy == 0, "push away from matrix does nothing")
    print("PASS: push adjacency")
end

-- opposing pushes cancel; same-axis pushes clamp to 1; different axes combine
do
    local a = { x = 3, y = 4, cmds = { "right" } }  -- target (4,4)
    local b = { x = 6, y = 4, cmds = { "left" } }   -- target (5,4)
    local dx, dy = Sim.net_push(4, 4, 2, 2, 10, 10, { a, b }, 1)
    assert(dx == 0 and dy == 0, "opposing pushes cancel")

    local c = { x = 3, y = 4, cmds = { "right" } }  -- target (4,4)
    local d = { x = 3, y = 5, cmds = { "right" } }  -- target (4,5)
    dx, dy = Sim.net_push(4, 4, 2, 2, 10, 10, { c, d }, 1)
    assert(dx == 1 and dy == 0, "same-axis pushes clamp to 1")

    local e = { x = 3, y = 4, cmds = { "right" } }  -- target (4,4)
    local f = { x = 4, y = 3, cmds = { "down" } }   -- target (4,4)
    dx, dy = Sim.net_push(4, 4, 2, 2, 10, 10, { e, f }, 1)
    assert(dx == 1 and dy == 1, "perpendicular pushes combine")
    print("PASS: push resolution")
end

-- pusher whose target is off the grid never fires
do
    local p = { x = 1, y = 1, cmds = { "left" } }  -- target (0,1) off grid
    local dx, dy = Sim.net_push(1, 1, 2, 2, 10, 10, { p }, 1)
    assert(dx == 0 and dy == 0, "off-grid target ignored")
    print("PASS: off-grid pusher")
end

-- blocking: only the grid edge blocks (pushers are not solid)
do
    assert(Sim.blocked(0, 1, 2, 2, 10, 10), "left edge blocks")
    assert(Sim.blocked(10, 1, 2, 2, 10, 10), "right edge blocks 2-wide")
    assert(Sim.blocked(1, 10, 2, 2, 10, 10), "bottom edge blocks 2-tall")
    assert(not Sim.blocked(9, 9, 2, 2, 10, 10), "fits in corner")
    print("PASS: blocking")
end

-- advance: moves, drags a 2-wide matrix over its own pusher, blocked at wall
do
    local st = {
        x = 1, y = 5, rows = 2, cols = 2, w = 10, h = 10,
        pushers = { { x = 1, y = 6, cmds = { "right", "right", "right" } } },
        n = 3, tick = 0,
    }
    assert(Sim.advance(st) == true and st.x == 2 and st.tick == 1, "tick 1 pushes over own pusher")
    assert(Sim.advance(st) == true and st.x == 3 and st.tick == 2, "tick 2 pushes again")
    assert(Sim.advance(st) == false and st.x == 3 and st.tick == 3, "tick 3: pusher out of reach")

    local wall = {
        x = 9, y = 5, rows = 2, cols = 2, w = 10, h = 10,
        pushers = { { x = 8, y = 5, cmds = { "right" } } },
        n = 1, tick = 0,
    }
    assert(Sim.advance(wall) == false and wall.x == 9, "push into wall is blocked")
    print("PASS: advance")
end

-- apply_op
do
    local m = Matrix.new(2, 2, { {1, 2}, {3, 4} })
    assert(Sim.apply_op({ kind = "op", op = "transpose" }, m):equals(Matrix.new(2, 2, { {1, 3}, {2, 4} })), "transpose")
    assert(Sim.apply_op({ kind = "pusher" }, m) == m, "non-op returns matrix unchanged")
    -- out-of-range rows are clamped, same-row add_rows is a no-op
    local s = Sim.apply_op({ kind = "op", op = "scale_row", params = { row = 9, scalar = 2 } }, m)
    assert(s:equals(Matrix.new(2, 2, { {1, 2}, {6, 8} })), "scale_row clamps row")
    local a = Sim.apply_op({ kind = "op", op = "add_rows", params = { src = 2, dst = 2, scalar = 1 } }, m)
    assert(a == m, "add_rows same row is a no-op")
    print("PASS: apply_op")
end

print("ALL TESTS PASSED")
