local Sim    = require("lua/game/pusher_sim")
local Matrix = require("lua/game/matrix_math")

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
    local moved1, blocked1 = Sim.advance(s)
    assert(moved1 == true and s.pushers[1].x == 2 and s.pushers[1].y == 1, "moves right")
    assert(blocked1 == false, "right: not blocked")
    local moved2, blocked2 = Sim.advance(s)
    assert(moved2 == true and s.pushers[1].x == 2 and s.pushers[1].y == 2, "moves down")
    assert(blocked2 == false, "down: not blocked")
    local moved3, blocked3 = Sim.advance(s)
    assert(moved3 == false and s.pushers[1].x == 2, "idle stays")
    assert(blocked3 == false, "idle: not blocked")
    local moved4, blocked4 = Sim.advance(s)
    assert(moved4 == false, "nil command is idle")
    assert(blocked4 == false, "nil command: not blocked")
    print("PASS: pusher moves")
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
    -- a pusher riding inside the matrix carries it along
    local r = st({ x = 1, y = 5, pushers = { P(1, 6, "right", "right") } })
    local _, blocked_r1 = Sim.advance(r)
    local _, blocked_r2 = Sim.advance(r)
    assert(r.x == 3 and r.pushers[1].x == 3, "inside pusher drags matrix")
    assert(blocked_r1 == false and blocked_r2 == false, "inside pusher drags: not blocked")
    print("PASS: push matrix")
end

-- blocking: grid edge stops pusher and matrix; matrix may not be shoved onto a pusher
do
    local s = st({ pushers = { P(1, 1, "left", "up") } })
    local moved_sl, blocked_sl = Sim.advance(s)
    assert(moved_sl == false and s.pushers[1].x == 1, "pusher stops at left edge")
    assert(blocked_sl == true, "left edge: blocked")
    local moved_su, blocked_su = Sim.advance(s)
    assert(moved_su == false and s.pushers[1].y == 1, "pusher stops at top edge")
    assert(blocked_su == true, "top edge: blocked")

    local w = st({ x = 9, pushers = { P(8, 5, "right") } })
    local moved_w, blocked_w = Sim.advance(w)
    assert(moved_w == false and w.x == 9 and w.pushers[1].x == 8, "matrix at wall: push does nothing")
    assert(blocked_w == true, "matrix at wall: blocked")

    local b = st({ pushers = { P(4, 5, "right"), P(7, 5, "idle") } })  -- B sits where the matrix would land
    local moved_b, blocked_b = Sim.advance(b)
    assert(moved_b == false and b.x == 5 and b.pushers[1].x == 4, "matrix cannot be shoved onto a pusher")
    assert(blocked_b == true, "matrix shove onto pusher: blocked")

    -- matrix cannot be shoved onto a pusher already inside the footprint
    -- matrix (1,5) cols=3: covers (1,5),(2,5),(3,5); B at (2,5) is in both old and new footprint after a right-push
    local c = st({ x=1, y=5, rows=1, cols=3, pushers = { P(0, 5, "right"), P(2, 5, "idle") } })
    local moved_c, blocked_c = Sim.advance(c)
    assert(moved_c == false and c.x == 1 and c.pushers[1].x == 0, "matrix cannot be shoved onto an already-inside pusher")
    assert(blocked_c == true, "matrix shove onto inside pusher: blocked")
    print("PASS: blocking")
end

-- pushers are solid to each other and act in order
do
    local s = st({ pushers = { P(1, 1, "right"), P(2, 1, "idle") } })
    local moved_s, blocked_s = Sim.advance(s)
    assert(moved_s == false and s.pushers[1].x == 1, "cannot walk into another pusher")
    assert(blocked_s == true, "collision with idle pusher: blocked")
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

    -- matrix shove blocked when new position overlaps a gap
    -- matrix at (1,2) cols=2 rows=2; pusher pushes right; new anchor (2,2) covers (2,2),(3,2),(2,3),(3,3); (3,3) is a gap
    local m = st({ x = 1, y = 2, rows = 2, cols = 2, pushers = { P(1, 3, "right") }, gaps = gaps })
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

-- ── Timeline scroll logic (pure-Lua, no LÖVE required) ───────────────────────
-- These mirror the math in MatrixScene:_timeline_layout and _timeline_click.

local function visible_count(slot_w_total, slot_w, slot_gap)
    return math.max(1, math.floor(slot_w_total / (slot_w + slot_gap)))
end

local function clamp_scroll_on_shrink(scroll, timeline_n, vis)
    return math.min(scroll, math.max(0, timeline_n - vis))
end

local function auto_scroll(cur_slot, scroll, vis)
    if cur_slot == 1 then
        return 0
    elseif cur_slot > scroll + vis then
        return cur_slot - vis
    elseif cur_slot <= scroll then
        return cur_slot - 1
    end
    return scroll
end

do
    -- visible_count: slot area of 316px, slot_w=22, gap=2 → 13 slots
    assert(visible_count(316, 22, 2) == 13, "316px -> 13 visible slots")
    -- very narrow area always returns at least 1
    assert(visible_count(5, 22, 2) == 1, "tiny area -> 1 visible slot")
    -- exactly fits 8 slots (8*24=192)
    assert(visible_count(192, 22, 2) == 8, "192px -> 8 slots")
    print("PASS: timeline visible_count")
end

do
    -- shrinking timeline_n clamps scroll so last slot stays visible
    -- n=10 -> 8, vis=5: scroll was 6, should clamp to max(0,8-5)=3
    assert(clamp_scroll_on_shrink(6, 8, 5) == 3, "scroll clamped after shrink")
    -- scroll already in bounds: unchanged
    assert(clamp_scroll_on_shrink(2, 8, 5) == 2, "scroll in bounds: unchanged")
    -- scroll=0 stays 0
    assert(clamp_scroll_on_shrink(0, 8, 5) == 0, "scroll=0 stays 0")
    -- timeline_n < vis: clamp to 0
    assert(clamp_scroll_on_shrink(3, 4, 5) == 0, "n < vis: scroll -> 0")
    print("PASS: timeline scroll clamp on shrink")
end

do
    -- auto-scroll: cur_slot wraps to 1 → scroll rewinds to 0
    assert(auto_scroll(1, 5, 5) == 0, "wrap to slot 1 resets scroll")
    -- cur_slot ahead of window: scroll forward
    assert(auto_scroll(10, 3, 5) == 5, "cur_slot past window: scroll forward")
    -- cur_slot at window right edge: no change
    assert(auto_scroll(8, 3, 5) == 3, "cur_slot at right edge: no change")
    -- cur_slot behind window: scroll back
    assert(auto_scroll(2, 5, 5) == 1, "cur_slot behind window: scroll back")
    -- cur_slot inside window: no change
    assert(auto_scroll(5, 3, 5) == 3, "cur_slot inside window: no change")
    print("PASS: timeline auto-scroll")
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

print("ALL TESTS PASSED")
