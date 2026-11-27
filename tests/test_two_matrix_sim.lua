-- Movement with two matrices (docs/archive/design/matrix-operand-ops.md, section 4).
local Sim = require("lua/game/pusher_sim")

local function P(x, y, dir) return { x = x, y = y, dir = dir } end
local function M(x, y, rows, cols) return { x = x, y = y, rows = rows or 1, cols = cols or 1 } end

-- a is the primary matrix, b the second one; pushers get ids in list order.
local function state(a, b, pushers, gaps)
    for i, p in ipairs(pushers) do p.id = i end
    return { x = a.x, y = a.y, rows = a.rows, cols = a.cols, second = b,
             w = 10, h = 10, tick = 0, pushers = pushers, gaps = gaps }
end

local function positions(s)
    local out = { s.x, s.y, s.second.x, s.second.y }
    for _, p in ipairs(s.pushers) do out[#out + 1] = p.x; out[#out + 1] = p.y end
    return table.concat(out, ",")
end

-- A successful tick; expected is "ax,ay,bx,by,p1x,p1y,...".
local function moves(name, s, expected, expect_moved)
    local moved, blocked, collided = Sim.advance(s)
    assert(not blocked and not collided, name .. ": unexpectedly blocked")
    assert(moved == (expect_moved ~= false), name .. ": moved = " .. tostring(moved))
    assert(positions(s) == expected, name .. ": got " .. positions(s))
    assert(s.tick == 1, name .. ": tick advances")
end

-- A failed tick: everything stays, pusher dirs are kept and the tick advances.
local function fails(name, s, expect_collided)
    local before, dirs = positions(s), {}
    for i, p in ipairs(s.pushers) do dirs[i] = p.dir end
    local moved, blocked, collided = Sim.advance(s)
    assert(blocked == true, name .. ": expected blocked")
    assert(collided == expect_collided, name .. ": collided = " .. tostring(collided))
    assert(moved == false, name .. ": a failed tick never reports movement")
    assert(positions(s) == before, name .. ": not rolled back, got " .. positions(s))
    for i, p in ipairs(s.pushers) do assert(p.dir == dirs[i], name .. ": dir kept") end
    assert(s.tick == 1, name .. ": tick advances")
end
local function blocks(name, s) fails(name, s, false) end
local function collides(name, s) fails(name, s, true) end

-- Without a second matrix the third result is false.
do
    local s = { x = 5, y = 5, rows = 1, cols = 1, w = 10, h = 10, tick = 0,
                pushers = { { id = 1, x = 4, y = 5, dir = "right" } } }
    local moved, blocked, collided = Sim.advance(s)
    assert(moved and blocked == false and collided == false and s.x == 6)
    print("PASS: single matrix returns collided = false")
end

-- Commands apply with two matrices, and a push moves only the matrix stepped into.
do
    local s = state(M(3, 2, 2, 2), M(3, 7), { P(2, 2) })
    local moved = Sim.advance(s, { { pusher = 1, cmd = "right" } })
    assert(moved and positions(s) == "4,2,3,7,3,2", positions(s))
    moves("second only", state(M(3, 2), M(3, 7, 2, 2), { P(5, 8, "left") }), "3,2,2,7,4,8")
    print("PASS: a push moves only its matrix")
end

-- Independent moves in one tick, including opposite directions on different matrices.
do
    moves("independent", state(M(3, 2), M(7, 7), { P(2, 2, "right"), P(8, 7, "left") }),
        "4,2,6,7,3,2,7,7")
    moves("idle", state(M(3, 2), M(7, 7), { P(1, 1) }), "3,2,7,7,1,1", false)
    moves("free pusher only", state(M(3, 2), M(7, 7), { P(1, 1, "right") }), "3,2,7,7,2,1")
    print("PASS: independent moves")
end

-- Forces combine per matrix: duplicates count once, perpendicular ones make a diagonal.
do
    moves("same direction", state(M(3, 2, 2, 1), M(7, 7), { P(2, 2, "right"), P(2, 3, "right") }),
        "4,2,7,7,3,2,3,3")
    moves("diagonal", state(M(7, 7), M(3, 3, 2, 2), { P(2, 4, "right"), P(4, 2, "down") }),
        "7,7,4,4,3,4,4,3")
    moves("both diagonal", state(M(2, 2, 2, 2), M(8, 7, 2, 2),
        { P(1, 3, "right"), P(3, 1, "down"), P(10, 7, "left"), P(8, 9, "up") }),
        "3,3,7,6,2,3,3,2,9,7,8,8")
    print("PASS: combined forces and diagonal")
end

-- Following: one matrix moves into cells the other leaves on the same tick. B is 2 rows tall
-- and pushed from its top row, so its bottom cell is vacated with no pusher in it.
do
    moves("primary follows", state(M(3, 5), M(4, 4, 2, 1), { P(2, 5, "right"), P(3, 4, "right") }),
        "4,5,5,4,3,5,4,4")
    moves("second follows", state(M(4, 4, 2, 1), M(3, 5), { P(2, 5, "right"), P(3, 4, "right") }),
        "5,4,4,5,3,5,4,4")
    -- A pusher may step out of the way of an arriving matrix.
    moves("lead pusher", state(M(3, 2), M(8, 8), { P(2, 2, "right"), P(4, 2, "down") }),
        "4,2,8,8,3,2,4,3")
    print("PASS: following into vacated cells")
end

-- Matrices may touch edge to edge.
do
    moves("ends touching", state(M(3, 5), M(5, 5), { P(2, 5, "right") }), "4,5,5,5,3,5")
    moves("slides along", state(M(3, 5), M(3, 6), { P(2, 5, "right") }), "4,5,3,6,3,5")
    print("PASS: touching")
end

-- Overlaps: head-on into one cell, and shoving into a stationary matrix (no chain push).
do
    collides("head-on", state(M(3, 5), M(5, 5), { P(2, 5, "right"), P(6, 5, "left") }))
    collides("into stationary second", state(M(3, 5), M(4, 5), { P(2, 5, "right") }))
    collides("into stationary primary", state(M(4, 5), M(3, 5), { P(2, 5, "right") }))
    collides("partial overlap", state(M(3, 4, 2, 2), M(5, 5, 2, 2), { P(2, 4, "right") }))
    print("PASS: overlap collides, no chain push")
end

-- Exchange: the final footprints are apart but each matrix ends where the other started. The
-- contact pushers end inside the other matrix, which must still report a collision.
do
    collides("head-on exchange", state(M(3, 5), M(4, 5), { P(2, 5, "right"), P(5, 5, "left") }))
    collides("vertical exchange", state(M(5, 4), M(5, 3), { P(5, 5, "up"), P(5, 2, "down") }))
    print("PASS: exchange collides")
end

-- Diagonal moves: neither corner cell may hold the other matrix after the tick.
do
    local function diagonal(extra)
        local pushers = { P(2, 3, "right"), P(3, 2, "down") }
        if extra then pushers[#pushers + 1] = extra end
        return pushers
    end
    -- A 1x1 cannot take two pushers on one cell, so the diagonal matrix is 2x2 at (3,3);
    -- its corner cells are (5,3) and (3,5).
    local function push() return { P(2, 4, "right"), P(4, 2, "down") } end
    collides("top-right corner", state(M(3, 3, 2, 2), M(5, 3), push()))
    collides("bottom-left corner", state(M(3, 3, 2, 2), M(3, 5), push()))
    collides("second is the diagonal one", state(M(5, 3), M(3, 3, 2, 2), push()))
    local into = push(); into[3] = P(7, 3, "left")
    collides("moves into the corner", state(M(3, 3, 2, 2), M(6, 3), into))
    local away = push(); away[3] = P(5, 4, "up")
    moves("leaves the corner", state(M(3, 3, 2, 2), M(5, 3), away), "4,4,5,2,3,4,4,3,5,3")
    -- Grid and gap corners stay "blocked", even when the matrices would also collide.
    blocks("gap corner", state(M(3, 3, 2, 2), M(5, 4), push(), { [5] = { [3] = true } }))
    blocks("same landing cell", state(M(3, 3), M(8, 8), diagonal()))
    print("PASS: diagonal corners and shared landing cell")
end

-- Wall, gap, edge, opposing and pusher problems are "blocked" and beat a collision.
do
    blocks("wall", state(M(10, 2), M(8, 8), { P(9, 2, "right") }))
    blocks("gap", state(M(8, 8), M(3, 2), { P(2, 2, "right") }, { [2] = { [4] = true } }))
    blocks("wall beats collision", state(M(3, 5), M(4, 5), { P(2, 5, "right"), P(4, 4, "down") },
        { [6] = { [4] = true } }))
    blocks("opposing beats collision",
        state(M(3, 5), M(4, 5), { P(2, 5, "right"), P(4, 4, "down"), P(4, 6, "up") }))
    blocks("stationary pusher beats collision",
        state(M(3, 4, 2, 1), M(4, 4), { P(2, 4, "right"), P(4, 5) }))
    blocks("walled pusher beats collision",
        state(M(3, 5), M(4, 5), { P(2, 5, "right"), P(1, 1, "left") }))
    blocks("pusher stepping into an arriving matrix",
        state(M(3, 5), M(8, 8), { P(2, 5, "right"), P(4, 4, "down") }))
    blocks("matrix shoved onto a pusher", state(M(8, 8), M(3, 5), { P(2, 5, "right"), P(4, 5) }))
    -- Without a collision, the other matrix's pusher inside the arriving one is a problem:
    -- B is pushed down by a pusher that takes the cell A moves into.
    blocks("other matrix's pusher in the way",
        state(M(3, 5), M(4, 5), { P(2, 5, "right"), P(4, 4, "down") }))
    print("PASS: pusher precedence")
end

-- A failed tick rolls back the successful move of the other matrix and every pusher.
do
    blocks("second at the wall", state(M(3, 2), M(10, 8), { P(2, 2, "right"), P(9, 8, "right") }))
    blocks("primary at the wall", state(M(10, 8), M(3, 2), { P(2, 2, "right"), P(9, 8, "right") }))
    blocks("later free pusher fails",
        state(M(3, 2), M(8, 8), { P(2, 2, "right"), P(5, 5, "right"), P(1, 1, "up") }))
    print("PASS: rollback")
end

print("ALL TWO MATRIX SIM TESTS PASSED")
