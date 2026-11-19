local Sim = {}

Sim.DIRS = {
    up    = { dx =  0, dy = -1 },
    down  = { dx =  0, dy =  1 },
    left  = { dx = -1, dy =  0 },
    right = { dx =  1, dy =  0 },
}

-- 1-based timeline slot for a 1-based tick, looping every n slots.
function Sim.slot(tick, n)
    return ((tick - 1) % n) + 1
end

local function sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
end

local function covers(x, y, rows, cols, cx, cy)
    return cx >= x and cx <= x + cols - 1 and cy >= y and cy <= y + rows - 1
end

local function pusher_at(pushers, cx, cy, skip)
    for _, q in ipairs(pushers) do
        if q ~= skip and q.x == cx and q.y == cy then return q end
    end
end

-- True if a matrix anchored at (nx, ny) would leave the grid or overlap a gap cell.
-- gaps is an optional {[y]={[x]=true}} lookup.
function Sim.blocked(nx, ny, rows, cols, w, h, gaps)
    if nx < 1 or ny < 1 or nx + cols - 1 > w or ny + rows - 1 > h then return true end
    if gaps then
        for dr = 0, rows - 1 do
            for dc = 0, cols - 1 do
                local gy, gx = ny + dr, nx + dc
                if gaps[gy] and gaps[gy][gx] then return true end
            end
        end
    end
    return false
end

-- Returns true if the matrix footprint anchored at (x,y) with the given rows/cols
-- is fully in-bounds, clear of gaps, and does not overlap any pusher.
function Sim.footprint_clear(x, y, rows, cols, w, h, gaps, pushers)
    if Sim.blocked(x, y, rows, cols, w, h, gaps) then return false end
    if pushers then
        for _, q in ipairs(pushers) do
            if q.x >= x and q.x <= x + cols - 1
               and q.y >= y and q.y <= y + rows - 1 then
                return false
            end
        end
    end
    return true
end

-- Run one tick. st: { x, y, rows, cols, w, h, pushers, n, tick } where x,y is the matrix
-- anchor and pushers is an array of { x, y, cmds }; cmds[slot] is "up"|"down"|"left"|"right"|"idle"|nil.
-- Pushers act one at a time in array order, each stepping one cell in its command direction:
--   * off the grid, or into another pusher's cell: the pusher stays put
--   * into a matrix cell: the matrix is shoved one cell the same way; if that would take it
--     off the grid or onto another pusher, nothing moves
-- Mutates st.tick, st.x/st.y and each pusher's x/y. Returns moved (bool): anything moved.
function Sim.advance(st)
    st.tick = st.tick + 1
    local slot    = Sim.slot(st.tick, st.n)
    local moved   = false
    local blocked = false
    for _, p in ipairs(st.pushers) do
        local d = Sim.DIRS[(p.cmds and p.cmds[slot]) or "idle"]
        if d then
            local tx, ty = p.x + d.dx, p.y + d.dy
            local ok = tx >= 1 and tx <= st.w and ty >= 1 and ty <= st.h
                       and not pusher_at(st.pushers, tx, ty, p)
                       and not (st.gaps and st.gaps[ty] and st.gaps[ty][tx])
            if ok and covers(st.x, st.y, st.rows, st.cols, tx, ty) then
                local nx, ny = st.x + d.dx, st.y + d.dy
                if Sim.blocked(nx, ny, st.rows, st.cols, st.w, st.h, st.gaps) then
                    ok = false
                else
                    for _, q in ipairs(st.pushers) do
                        if q ~= p and covers(nx, ny, st.rows, st.cols, q.x, q.y) then
                            ok = false; break
                        end
                    end
                    if ok then st.x, st.y = nx, ny end
                end
            end
            if ok then p.x, p.y = tx, ty; moved = true else blocked = true end
        end
    end
    return moved, blocked
end

-- Applies an op tile to a matrix; row params are clamped to the matrix size.
function Sim.apply_op(tile, matrix)
    if tile.kind ~= "op" then return matrix end
    local op = tile.op
    local p  = tile.params or {}
    local n  = matrix.rows

    if op == "transpose" then
        return matrix:transpose()
    elseif op == "negate" then
        return matrix:negate()
    elseif op == "scale_row" then
        local r = math.max(1, math.min(n, p.row or 1))
        return matrix:scale_row(r, p.scalar or 1)
    elseif op == "swap_rows" then
        local a = math.max(1, math.min(n, p.row_a or 1))
        local b = math.max(1, math.min(n, p.row_b or 2))
        return matrix:swap_rows(a, b)
    elseif op == "scalar_mul" then
        return matrix:scalar_mul(p.scalar or 1)
    elseif op == "add_matrix" then
        local rows = tile.tile_rows or 1
        local cols = tile.tile_cols or 1
        local Matrix = require("game/matrix_math")
        local addend = Matrix.new(rows, cols, tile.values)
        return matrix:add_matrix(addend)
    elseif op == "sub_matrix" then
        local rows = tile.tile_rows or 1
        local cols = tile.tile_cols or 1
        local Matrix = require("game/matrix_math")
        local operand = Matrix.new(rows, cols, tile.values)
        return matrix:sub_matrix(operand)
    elseif op == "mul_matrix" then
        local rows = tile.tile_rows or 1
        local cols = tile.tile_cols or 1
        local Matrix = require("game/matrix_math")
        local factor = Matrix.new(rows, cols, tile.values)
        return matrix:mul_matrix(factor)
    elseif op == "set_row" then
        local row = p.row or 1
        local values = {}
        local tv = tile.values or {{}}
        for c = 1, tile.tile_cols or 1 do
            values[c] = (tv[1] and tv[1][c]) or 0
        end
        return matrix:set_row(row, values)
    end
    return matrix
end

return Sim
