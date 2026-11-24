local Sim    = require("lua/game/pusher_sim")
local Matrix = require("lua/game/matrix_math")

-- Puzzle-scene UI overhaul (Task 2): the sim's input model changed from looping per-pusher
-- cmds[slot] (with "idle") to a persistent per-pusher `dir` plus a per-tick `commands` list
-- { {pusher=id, cmd=cmd}, ... } passed to Sim.advance(st, commands). Sim.slot / st.n are gone.
-- Every rewritten test below keeps its physics meaning (same positions, moves, blocks); only
-- the way the direction is supplied changed: a pusher built with P(x, y, dir) already has
-- that dir (what a command at tick 1 would give it), and tests that changed direction mid-run
-- now issue a command at that tick. "idle" became nil/"stop" (not moving). The scroll-math
-- tests that mirrored the old looping/resizable timeline UI were removed; Task 5/7 cover the
-- new timeline bar.

local function st(over)
    local t = { x = 5, y = 5, rows = 2, cols = 2, w = 10, h = 10, pushers = {}, tick = 0 }
    for k, v in pairs(over) do t[k] = v end
    for i, q in ipairs(t.pushers) do q.id = q.id or i end
    return t
end
local function P(x, y, dir) return { x = x, y = y, dir = dir } end
local function cmd(id, c) return { pusher = id, cmd = c } end

-- a pusher moves one cell per tick in its dir; commands change dir; stop halts
do
    local s = st({ pushers = { P(1, 1) } })
    local moved1, blocked1 = Sim.advance(s, { cmd(1, "right") })
    assert(moved1 == true and s.pushers[1].x == 2 and s.pushers[1].y == 1, "moves right")
    assert(blocked1 == false, "right: not blocked")
    local moved2, blocked2 = Sim.advance(s, { cmd(1, "down") })
    assert(moved2 == true and s.pushers[1].x == 2 and s.pushers[1].y == 2, "moves down")
    assert(blocked2 == false, "down: not blocked")
    local moved3, blocked3 = Sim.advance(s, { cmd(1, "stop") })
    assert(moved3 == false and s.pushers[1].x == 2, "stop stays")
    assert(blocked3 == false, "stop: not blocked")
    local moved4, blocked4 = Sim.advance(s)
    assert(moved4 == false, "no command after stop stays stopped")
    assert(blocked4 == false, "stopped: not blocked")
    assert(s.tick == 4, "tick incremented each advance")
    print("PASS: pusher moves")
end

-- a command persists across empty ticks (nil and {} commands)
do
    local s = st({ pushers = { P(1, 1) } })
    Sim.advance(s, { cmd(1, "right") })
    Sim.advance(s)
    Sim.advance(s, {})
    assert(s.pushers[1].x == 4 and s.pushers[1].dir == "right", "right persists over empty ticks")
    print("PASS: command persists")
end

-- a pusher that never gets a command never moves
do
    local s = st({ pushers = { P(3, 3) } })
    local moved, blocked = Sim.advance(s)
    assert(moved == false and blocked == false and s.pushers[1].x == 3, "no command: stays")
    print("PASS: no command stays stopped")
end

-- a blocked pusher keeps its dir and goes on when the obstacle clears
do
    local s = st({ pushers = { P(1, 1), P(3, 1) } })
    Sim.advance(s, { cmd(1, "right"), cmd(2, "stop") })   -- A to x=2
    local _, blocked = Sim.advance(s)                      -- A blocked by B at x=3
    assert(blocked == true and s.pushers[1].x == 2, "blocked by other pusher")
    assert(s.pushers[1].dir == "right", "blocked pusher keeps dir")
    Sim.advance(s, { cmd(2, "down") })                     -- B leaves
    assert(s.pushers[2].y == 2, "B moved away")
    assert(s.pushers[1].x == 2, "A acts before B in array order, still blocked this tick")
    Sim.advance(s)
    assert(s.pushers[1].x == 3, "A resumes once the cell is free")
    -- wall: dir kept as well
    local w = st({ pushers = { P(1, 1) } })
    Sim.advance(w, { cmd(1, "left") })
    assert(w.pushers[1].dir == "left", "wall-blocked pusher keeps dir")
    print("PASS: blocked keeps dir")
end

-- two commands in one tick for different pushers; unknown id ignored
do
    local s = st({ pushers = { P(1, 1), P(1, 8) } })
    Sim.advance(s, { cmd(1, "right"), cmd(2, "up"), cmd(99, "left") })
    assert(s.pushers[1].x == 2 and s.pushers[1].y == 1, "A moved right")
    assert(s.pushers[2].x == 1 and s.pushers[2].y == 7, "B moved up in the same tick")
    print("PASS: two commands same tick")
end

-- walking into the matrix shoves it one cell
do
    local s = st({ pushers = { P(4, 5, "right") } })  -- matrix covers (5..6, 5..6)
    local moved_s, blocked_s = Sim.advance(s)
    assert(moved_s == true, "moved")
    assert(blocked_s == false, "matrix shove: not blocked")
    assert(s.x == 6 and s.y == 5, "matrix shoved right")
    assert(s.pushers[1].x == 5 and s.pushers[1].y == 5, "pusher followed into the vacated cell")
    -- walking beside it does not
    local t = st({ pushers = { P(4, 8, "right") } })
    local _, blocked_t = Sim.advance(t)
    assert(t.x == 5 and t.pushers[1].x == 5, "no contact, matrix untouched")
    assert(blocked_t == false, "beside matrix: not blocked")
    -- a pusher that consistently follows the matrix one step behind carries it tick by tick;
    -- after each push the matrix moves one cell ahead, putting the pusher back outside
    local r = st({ x = 1, y = 5, pushers = { P(0, 5, "right") } })
    local _, blocked_r1 = Sim.advance(r)
    local _, blocked_r2 = Sim.advance(r)
    assert(r.x == 3 and r.pushers[1].x == 2, "follower pusher carries matrix 2 cells")
    assert(blocked_r1 == false and blocked_r2 == false, "follower carry: not blocked")
    print("PASS: push matrix")
end

-- blocking: grid edge stops pusher and matrix; matrix may not be shoved onto a pusher
do
    local s = st({ pushers = { P(1, 1) } })
    local moved_sl, blocked_sl = Sim.advance(s, { cmd(1, "left") })
    assert(moved_sl == false and s.pushers[1].x == 1, "pusher stops at left edge")
    assert(blocked_sl == true, "left edge: blocked")
    local moved_su, blocked_su = Sim.advance(s, { cmd(1, "up") })
    assert(moved_su == false and s.pushers[1].y == 1, "pusher stops at top edge")
    assert(blocked_su == true, "top edge: blocked")

    local w = st({ x = 9, pushers = { P(8, 5, "right") } })
    local moved_w, blocked_w = Sim.advance(w)
    assert(moved_w == false and w.x == 9 and w.pushers[1].x == 8, "matrix at wall: push does nothing")
    assert(blocked_w == true, "matrix at wall: blocked")

    local b = st({ pushers = { P(4, 5, "right"), P(7, 5) } })  -- B sits where the matrix would land
    local moved_b, blocked_b = Sim.advance(b)
    assert(moved_b == false and b.x == 5 and b.pushers[1].x == 4, "matrix cannot be shoved onto a pusher")
    assert(blocked_b == true, "matrix shove onto pusher: blocked")

    -- matrix cannot be shoved onto a pusher already inside the footprint
    -- matrix (1,5) cols=3: covers (1,5),(2,5),(3,5); B at (2,5) is in both old and new footprint after a right-push
    local c = st({ x=1, y=5, rows=1, cols=3, pushers = { P(0, 5, "right"), P(2, 5) } })
    local moved_c, blocked_c = Sim.advance(c)
    assert(moved_c == false and c.x == 1 and c.pushers[1].x == 0, "matrix cannot be shoved onto an already-inside pusher")
    assert(blocked_c == true, "matrix shove onto inside pusher: blocked")
    print("PASS: blocking")
end

-- pushers are solid to each other and act in order
do
    local s = st({ pushers = { P(1, 1, "right"), P(2, 1) } })
    local moved_s, blocked_s = Sim.advance(s)
    assert(moved_s == false and s.pushers[1].x == 1, "cannot walk into another pusher")
    assert(blocked_s == true, "collision with stopped pusher: blocked")
    local t = st({ pushers = { P(1, 1, "right"), P(2, 1, "down") } })
    local _, blocked_t = Sim.advance(t)
    assert(t.pushers[1].x == 1 and t.pushers[2].y == 2, "first acts first: still blocked; second moves away")
    assert(blocked_t == true, "first pusher blocked even though second moved: blocked")
    local u = st({ pushers = { P(2, 1, "down"), P(1, 1, "right") } })
    local _, blocked_u = Sim.advance(u)
    assert(u.pushers[2].x == 2, "with the other listed first, the cell is free")
    assert(blocked_u == false, "both pushers move freely: not blocked")
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
    local moved_s, blocked_s = Sim.advance(s)
    assert(moved_s == false and s.pushers[1].x == 2, "pusher cannot enter gap")
    assert(blocked_s == true, "gap block: blocked")

    -- outside pusher shove blocked when new matrix position overlaps a gap
    -- matrix at (1,2) cols=2 rows=2; pusher at (0,2) outside, pushes right;
    -- new anchor (2,2) covers (2,2),(3,2),(2,3),(3,3); (3,3) is a gap → blocked
    local m = st({ x = 1, y = 2, rows = 2, cols = 2, pushers = { P(0, 2, "right") }, gaps = gaps })
    local moved_m, blocked_m = Sim.advance(m)
    assert(not moved_m or (m.x == 1), "matrix cannot be shoved onto a gap cell")
    assert(blocked_m == true, "matrix shove into gap: blocked")

    -- no gaps table: existing behaviour unchanged
    local n = st({ pushers = { P(2, 3, "right") } })
    local moved_n, blocked_n = Sim.advance(n)
    assert(moved_n == true and n.pushers[1].x == 3, "no gaps: pusher moves freely")
    assert(blocked_n == false, "no gaps: not blocked")
    print("PASS: gap blocking")
end

-- diagonal corner cells must be gap-free: matrix at (2,2) 2×2, pushing (+1,+1).
-- top-right corner = (4,2); bottom-left corner = (2,4).
do
    -- gap at top-right corner blocks the diagonal
    local g1 = { [2] = { [4] = true } }
    local d1 = st({ x=2, y=2, rows=2, cols=2,
        pushers = { P(1, 2, "right"), P(3, 1, "down") }, gaps = g1 })
    local moved_d1, blocked_d1 = Sim.advance(d1)
    assert(not moved_d1 and d1.x == 2, "diagonal blocked by top-right corner gap: matrix stayed")
    assert(blocked_d1, "diagonal blocked by top-right corner gap: blocked=true")

    -- gap at bottom-left corner also blocks
    local g2 = { [4] = { [2] = true } }
    local d2 = st({ x=2, y=2, rows=2, cols=2,
        pushers = { P(1, 2, "right"), P(3, 1, "down") }, gaps = g2 })
    local moved_d2, blocked_d2 = Sim.advance(d2)
    assert(not moved_d2 and d2.x == 2, "diagonal blocked by bottom-left corner gap: matrix stayed")
    assert(blocked_d2, "diagonal blocked by bottom-left corner gap: blocked=true")

    -- no corner gaps: diagonal move succeeds
    local d3 = st({ x=2, y=2, rows=2, cols=2,
        pushers = { P(1, 2, "right"), P(3, 1, "down") } })
    local moved_d3, blocked_d3 = Sim.advance(d3)
    assert(moved_d3 and d3.x == 3 and d3.y == 3, "diagonal with clear corners succeeds")
    assert(not blocked_d3, "diagonal with clear corners: not blocked")
    print("PASS: diagonal corner gap blocking")
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
    local s2x3_ok = st({ x = 3, y = 5, rows = 2, cols = 3, pushers = { P(2, 5, "right") }, gaps = gaps })
    local _, blocked_ok = Sim.advance(s2x3_ok)
    assert(blocked_ok == false, "2x3 fits through 2-row corridor: not blocked")

    -- 2x3 anchor at (3,4): new anchor (4,4) covers rows 4,5; y=4 is blocked → blocked
    local s2x3_blk = st({ x = 3, y = 4, rows = 2, cols = 3, pushers = { P(2, 4, "right") }, gaps = gaps })
    local _, blocked_2x3 = Sim.advance(s2x3_blk)
    assert(s2x3_blk.x == 3, "2x3 blocked when footprint overlaps gap")
    assert(blocked_2x3 == true, "2x3 footprint overlaps gap: blocked")

    -- 3x2 anchor at (3,5): new anchor (4,5) covers cols 4,5 rows 5,6,7; y=7 is blocked → blocked
    local s3x2_blk = st({ x = 3, y = 5, rows = 3, cols = 2, pushers = { P(2, 5, "right") }, gaps = gaps })
    local _, blocked_3x2 = Sim.advance(s3x2_blk)
    assert(s3x2_blk.x == 3, "3x2 cannot fit through 2-row corridor")
    assert(blocked_3x2 == true, "3x2 cannot fit through corridor: blocked")
    print("PASS: nxm gap corridor")
end

-- footprint_clear: bounds + gap + pusher checks
do
    -- valid footprint
    assert(Sim.footprint_clear(5, 5, 2, 2, 10, 10, nil, {}),   "valid footprint clears")
    -- off-board (extends past right edge)
    assert(not Sim.footprint_clear(9, 5, 1, 3, 10, 10, nil, {}), "off-board footprint blocked")
    -- off-board (extends past bottom edge)
    assert(not Sim.footprint_clear(5, 9, 3, 1, 10, 10, nil, {}), "off-board footprint blocked (bottom)")
    -- overlaps a gap cell
    local gaps = {[7]={[10]=true}}
    assert(not Sim.footprint_clear(8, 7, 1, 3, 10, 10, gaps, {}), "gap overlap blocked")
    -- overlaps a pusher
    local pushers = {{x=6, y=5}}
    assert(not Sim.footprint_clear(5, 5, 2, 2, 10, 10, nil, pushers), "pusher overlap blocked")
    -- pusher outside footprint: allowed
    local pushers2 = {{x=8, y=5}}
    assert(Sim.footprint_clear(5, 5, 2, 2, 10, 10, nil, pushers2), "pusher outside footprint: ok")
    print("PASS: footprint_clear")
end

-- add_rows (was missing from apply_op — now fixed)
do
    local inp = Matrix.new(3,3,{{2,0,0},{4,1,0},{0,0,1}})
    local step1 = Sim.apply_op({kind="op", op="scale_row", params={row=1, scalar=0.5}}, inp)
    local step2 = Sim.apply_op({kind="op", op="add_rows",  params={src=1, dst=2, scalar=-4}}, step1)
    assert(step2:equals(Matrix.new(3,3,{{1,0,0},{0,1,0},{0,0,1}})), "add_rows fix: puzzle 14 chain")
    print("PASS: add_rows fix")
end

-- scale_col
do
    local inp = Matrix.new(2,2,{{1,2},{3,4}})
    local r = Sim.apply_op({kind="op", op="scale_col", params={col=2, scalar=3}}, inp)
    assert(r:equals(Matrix.new(2,2,{{1,6},{3,12}})), "apply_op scale_col")
    print("PASS: apply_op scale_col")
end

-- swap_cols
do
    local inp = Matrix.new(2,3,{{1,2,3},{4,5,6}})
    local r = Sim.apply_op({kind="op", op="swap_cols", params={col_a=1, col_b=3}}, inp)
    assert(r:equals(Matrix.new(2,3,{{3,2,1},{6,5,4}})), "apply_op swap_cols")
    print("PASS: apply_op swap_cols")
end

-- add_cols
do
    local inp = Matrix.new(2,2,{{1,0},{2,0}})
    local r = Sim.apply_op({kind="op", op="add_cols", params={src=1, dst=2, scalar=3}}, inp)
    assert(r:equals(Matrix.new(2,2,{{1,3},{2,6}})), "apply_op add_cols")
    print("PASS: apply_op add_cols")
end

-- set_col
do
    local inp = Matrix.new(3,2,{{1,2},{3,4},{5,6}})
    local r = Sim.apply_op({kind="op", op="set_col", params={col=2},
        tile_rows=3, values={{9},{8},{7}}}, inp)
    assert(r:equals(Matrix.new(3,2,{{1,9},{3,8},{5,7}})), "apply_op set_col")
    print("PASS: apply_op set_col")
end

-- rotate_90
do
    local inp = Matrix.new(2,3,{{1,2,3},{4,5,6}})
    local r = Sim.apply_op({kind="op", op="rotate_90", params={}}, inp)
    assert(r:equals(Matrix.new(3,2,{{4,1},{5,2},{6,3}})), "apply_op rotate_90")
    print("PASS: apply_op rotate_90")
end

-- flip_h
do
    local inp = Matrix.new(2,3,{{1,2,3},{4,5,6}})
    local r = Sim.apply_op({kind="op", op="flip_h", params={}}, inp)
    assert(r:equals(Matrix.new(2,3,{{3,2,1},{6,5,4}})), "apply_op flip_h")
    print("PASS: apply_op flip_h")
end

-- flip_v
do
    local inp = Matrix.new(3,2,{{1,2},{3,4},{5,6}})
    local r = Sim.apply_op({kind="op", op="flip_v", params={}}, inp)
    assert(r:equals(Matrix.new(3,2,{{5,6},{3,4},{1,2}})), "apply_op flip_v")
    print("PASS: apply_op flip_v")
end

-- abs
do
    local inp = Matrix.new(2,2,{{-1,2},{-3,-4}})
    local r = Sim.apply_op({kind="op", op="abs", params={}}, inp)
    assert(r:equals(Matrix.new(2,2,{{1,2},{3,4}})), "apply_op abs")
    print("PASS: apply_op abs")
end

-- sub_matrix
do
    local m = Matrix.new(2, 2, { {3, 4}, {5, 6} })
    local r = Sim.apply_op({ kind = "op", op = "sub_matrix",
        tile_rows = 2, tile_cols = 2, values = { {1, 2}, {3, 4} } }, m)
    assert(r:equals(Matrix.new(2, 2, { {2, 2}, {2, 2} })), "apply_op sub_matrix")
    print("PASS: apply_op sub_matrix")
end

-- mul_matrix (element-wise)
do
    local m = Matrix.new(2, 2, { {2, 3}, {4, 5} })
    local r = Sim.apply_op({ kind = "op", op = "mul_matrix",
        tile_rows = 2, tile_cols = 2, values = { {2, 2}, {2, 2} } }, m)
    assert(r:equals(Matrix.new(2, 2, { {4, 6}, {8, 10} })), "apply_op mul_matrix")
    print("PASS: apply_op mul_matrix")
end

-- set_row (row=2)
do
    local m = Matrix.new(2, 2, { {1, 2}, {3, 4} })
    local r = Sim.apply_op({ kind = "op", op = "set_row",
        params = { row = 2 }, tile_cols = 2, values = { {10, 20} } }, m)
    assert(r:equals(Matrix.new(2, 2, { {1, 2}, {10, 20} })), "apply_op set_row row=2")
    print("PASS: apply_op set_row")
end

-- add_cols src==dst is a no-op
do
    local m = Matrix.new(2, 2, { {1, 2}, {3, 4} })
    local r = Sim.apply_op({ kind = "op", op = "add_cols",
        params = { src = 1, dst = 1, scalar = 5 } }, m)
    assert(r == m, "add_cols same col is a no-op")
    print("PASS: apply_op add_cols src==dst no-op")
end

-- apply_op fallback: unknown op returns matrix unchanged (line 173)
do
    local m = Matrix.new(2, 2, { {1, 2}, {3, 4} })
    local result = Sim.apply_op({ kind = "op", op = "unknown_op_xyz" }, m)
    assert(result == m, "apply_op unknown op returns matrix unchanged")
    print("PASS: apply_op unknown op fallback (line 173)")
end

-- swap_rows
do
    local m = Matrix.new(2, 2, { {1, 2}, {3, 4} })
    local r = Sim.apply_op({ kind = "op", op = "swap_rows", params = { row_a = 1, row_b = 2 } }, m)
    assert(r:equals(Matrix.new(2, 2, { {3, 4}, {1, 2} })), "apply_op swap_rows")
    print("PASS: apply_op swap_rows")
end

-- scalar_mul
do
    local m = Matrix.new(2, 2, { {1, 2}, {3, 4} })
    local r = Sim.apply_op({ kind = "op", op = "scalar_mul", params = { scalar = 3 } }, m)
    assert(r:equals(Matrix.new(2, 2, { {3, 6}, {9, 12} })), "apply_op scalar_mul")
    print("PASS: apply_op scalar_mul")
end

-- add_matrix
do
    local m = Matrix.new(2, 2, { {1, 2}, {3, 4} })
    local r = Sim.apply_op({ kind = "op", op = "add_matrix",
        tile_rows = 2, tile_cols = 2, values = { {10, 20}, {30, 40} } }, m)
    assert(r:equals(Matrix.new(2, 2, { {11, 22}, {33, 44} })), "apply_op add_matrix")
    print("PASS: apply_op add_matrix")
end

print("ALL TESTS PASSED")
