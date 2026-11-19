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

    -- matrix cannot be shoved onto a pusher already inside the footprint
    -- matrix (1,5) cols=3: covers (1,5),(2,5),(3,5); B at (2,5) is in both old and new footprint after a right-push
    local c = st({ x=1, y=5, rows=1, cols=3, pushers = { P(0, 5, "right"), P(2, 5, "idle") } })
    assert(Sim.advance(c) == false and c.x == 1 and c.pushers[1].x == 0, "matrix cannot be shoved onto an already-inside pusher")
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

-- gap cells: pusher cannot enter; matrix cannot be shoved onto or through
do
    local gaps = { [3] = { [3] = true } }

    -- pusher blocked by a gap cell
    local s = st({ pushers = { P(2, 3, "right") }, gaps = gaps })
    assert(Sim.advance(s) == false and s.pushers[1].x == 2, "pusher cannot enter gap")

    -- matrix shove blocked when new position overlaps a gap
    -- matrix at (1,2) cols=2 rows=2; pusher pushes right; new anchor (2,2) covers (2,2),(3,2),(2,3),(3,3); (3,3) is a gap
    local m = st({ x = 1, y = 2, rows = 2, cols = 2, pushers = { P(1, 3, "right") }, gaps = gaps })
    local moved = Sim.advance(m)
    assert(not moved or (m.x == 1), "matrix cannot be shoved onto a gap cell")

    -- no gaps table: existing behaviour unchanged
    local n = st({ pushers = { P(2, 3, "right") } })
    assert(Sim.advance(n) == true and n.pushers[1].x == 3, "no gaps: pusher moves freely")
    print("PASS: gap blocking")
end

-- nxm matrix: transpose swaps dimensions, Sim.blocked uses actual rows/cols
do
    -- corridor at x=5,6: 2-row opening at y=5,6 (matches puzzle 11's gap=2 layout)
    local gaps = {}
    for y = 1, 10 do
        if y < 5 or y > 6 then
            gaps[y] = gaps[y] or {}
            gaps[y][5] = true
            gaps[y][6] = true
        end
    end

    -- 2x3 anchor at (3,5): new anchor (4,5) covers cols 4,5,6 rows 5,6; y=5,6 open → allowed
    local s2x3_ok = st({ x = 3, y = 5, rows = 2, cols = 3, pushers = { P(3, 4, "down") }, gaps = gaps })
    assert(Sim.advance(s2x3_ok) ~= nil, "2x3 fits through 2-row corridor")

    -- 2x3 anchor at (3,4): new anchor (4,4) covers rows 4,5; y=4 is blocked → blocked
    local s2x3_blk = st({ x = 3, y = 4, rows = 2, cols = 3, pushers = { P(3, 3, "down") }, gaps = gaps })
    Sim.advance(s2x3_blk)
    assert(s2x3_blk.x == 3, "2x3 blocked when footprint overlaps gap")

    -- 3x2 anchor at (3,5): new anchor (4,5) covers cols 4,5 rows 5,6,7; y=7 is blocked → blocked
    local s3x2_blk = st({ x = 3, y = 5, rows = 3, cols = 2, pushers = { P(3, 4, "down") }, gaps = gaps })
    Sim.advance(s3x2_blk)
    assert(s3x2_blk.x == 3, "3x2 cannot fit through 2-row corridor")
    print("PASS: nxm gap corridor")
end

print("ALL TESTS PASSED")
