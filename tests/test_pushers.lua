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

local function st(over)
    local t = { x = 5, y = 5, rows = 2, cols = 2, w = 10, h = 10, pushers = {}, n = 4, tick = 0 }
    for k, v in pairs(over) do t[k] = v end
    return t
end
local function P(x, y, ...) return { x = x, y = y, cmds = { ... } } end

-- a pusher moves one cell per command; idle/nil stay put
do
    local s = st({ pushers = { P(1, 1, "right", "down", "idle") } })
    assert(Sim.advance(s) == true and s.pushers[1].x == 2 and s.pushers[1].y == 1, "moves right")
    assert(Sim.advance(s) == true and s.pushers[1].x == 2 and s.pushers[1].y == 2, "moves down")
    assert(Sim.advance(s) == false and s.pushers[1].x == 2, "idle stays")
    assert(Sim.advance(s) == false, "nil command is idle")
    print("PASS: pusher moves")
end

-- walking into the matrix shoves it one cell
do
    local s = st({ pushers = { P(4, 5, "right") } })  -- matrix covers (5..6, 5..6)
    assert(Sim.advance(s) == true, "moved")
    assert(s.x == 6 and s.y == 5, "matrix shoved right")
    assert(s.pushers[1].x == 5 and s.pushers[1].y == 5, "pusher followed into the vacated cell")
    -- walking beside it does not
    local t = st({ pushers = { P(4, 8, "right") } })
    Sim.advance(t)
    assert(t.x == 5 and t.pushers[1].x == 5, "no contact, matrix untouched")
    -- a pusher riding inside the matrix carries it along
    local r = st({ x = 1, y = 5, pushers = { P(1, 6, "right", "right") } })
    Sim.advance(r); Sim.advance(r)
    assert(r.x == 3 and r.pushers[1].x == 3, "inside pusher drags matrix")
    print("PASS: push matrix")
end

-- blocking: grid edge stops pusher and matrix; matrix may not be shoved onto a pusher
do
    local s = st({ pushers = { P(1, 1, "left", "up") } })
    assert(Sim.advance(s) == false and s.pushers[1].x == 1, "pusher stops at left edge")
    assert(Sim.advance(s) == false and s.pushers[1].y == 1, "pusher stops at top edge")

    local w = st({ x = 9, pushers = { P(8, 5, "right") } })
    assert(Sim.advance(w) == false and w.x == 9 and w.pushers[1].x == 8, "matrix at wall: push does nothing")

    local b = st({ pushers = { P(4, 5, "right"), P(7, 5, "idle") } })  -- B sits where the matrix would land
    assert(Sim.advance(b) == false and b.x == 5 and b.pushers[1].x == 4, "matrix cannot be shoved onto a pusher")
    print("PASS: blocking")
end

-- pushers are solid to each other and act in order
do
    local s = st({ pushers = { P(1, 1, "right"), P(2, 1, "idle") } })
    assert(Sim.advance(s) == false and s.pushers[1].x == 1, "cannot walk into another pusher")
    local t = st({ pushers = { P(1, 1, "right"), P(2, 1, "down") } })
    Sim.advance(t)
    assert(t.pushers[1].x == 1 and t.pushers[2].y == 2, "first acts first: still blocked; second moves away")
    local u = st({ pushers = { P(2, 1, "down"), P(1, 1, "right") } })
    Sim.advance(u)
    assert(u.pushers[2].x == 2, "with the other listed first, the cell is free")
    print("PASS: pusher collision")
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
