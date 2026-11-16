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

-- pushers: array of { x, y, cmds }, cmds[slot] is "up"|"down"|"left"|"right"|"idle"|nil.
-- A pusher is active when the matrix covers the cell next to it in its command direction.
-- Returns the net (dx, dy): vectors summed, each axis clamped to -1..1.
function Sim.net_push(x, y, rows, cols, w, h, pushers, slot)
    local sx, sy = 0, 0
    for _, p in ipairs(pushers) do
        local d = Sim.DIRS[(p.cmds and p.cmds[slot]) or "idle"]
        if d then
            local tx, ty = p.x + d.dx, p.y + d.dy
            local in_grid = tx >= 1 and tx <= w and ty >= 1 and ty <= h
            if in_grid and tx >= x and tx <= x + cols - 1
                       and ty >= y and ty <= y + rows - 1 then
                sx = sx + d.dx
                sy = sy + d.dy
            end
        end
    end
    return sign(sx), sign(sy)
end

-- True if a matrix anchored at (nx, ny) would leave the grid. Pushers are not solid:
-- the matrix may slide over them (otherwise it could never travel past its own pushers).
function Sim.blocked(nx, ny, rows, cols, w, h)
    return nx < 1 or ny < 1 or nx + cols - 1 > w or ny + rows - 1 > h
end

-- Run one tick. st: { x, y, rows, cols, w, h, pushers, n, tick }.
-- Increments st.tick, moves st.x/st.y when a push succeeds, returns moved (bool).
function Sim.advance(st)
    st.tick = st.tick + 1
    local slot = Sim.slot(st.tick, st.n)
    local dx, dy = Sim.net_push(st.x, st.y, st.rows, st.cols, st.w, st.h, st.pushers, slot)
    if dx == 0 and dy == 0 then return false end
    local nx, ny = st.x + dx, st.y + dy
    if Sim.blocked(nx, ny, st.rows, st.cols, st.w, st.h) then return false end
    st.x, st.y = nx, ny
    return true
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
    elseif op == "add_rows" then
        local src = math.max(1, math.min(n, p.src or 1))
        local dst = math.max(1, math.min(n, p.dst or 2))
        if src == dst then return matrix end
        return matrix:add_rows(src, dst, p.scalar or 1)
    elseif op == "swap_rows" then
        local a = math.max(1, math.min(n, p.row_a or 1))
        local b = math.max(1, math.min(n, p.row_b or 2))
        return matrix:swap_rows(a, b)
    elseif op == "scalar_mul" then
        return matrix:scalar_mul(p.scalar or 1)
    end
    return matrix
end

return Sim
