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

    -- Pass 1: classify each commanded pusher.
    -- contact: its step lands on a matrix cell (using start-of-tick positions).
    -- non_contact: everything else (wall, gap, another pusher, or not touching the matrix).
    local contacts     = {}
    local non_contacts = {}
    for _, p in ipairs(st.pushers) do
        local d = Sim.DIRS[(p.cmds and p.cmds[slot]) or "idle"]
        if d then
            local tx, ty  = p.x + d.dx, p.y + d.dy
            local can_step = tx >= 1 and tx <= st.w and ty >= 1 and ty <= st.h
                             and not pusher_at(st.pushers, tx, ty, p)
                             and not (st.gaps and st.gaps[ty] and st.gaps[ty][tx])
            if can_step and covers(st.x, st.y, st.rows, st.cols, tx, ty) then
                contacts[#contacts+1] = { p=p, d=d, tx=tx, ty=ty }
            else
                non_contacts[#non_contacts+1] = { p=p, tx=tx, ty=ty }
            end
        end
    end

    -- Pass 2: aggregate contact forces (deduplicate same direction), attempt one combined move.
    if #contacts > 0 then
        -- Collect unique direction vectors.
        local unique_dirs = {}
        local seen_dir = {}
        for _, c in ipairs(contacts) do
            local key = c.d.dx .. "," .. c.d.dy
            if not seen_dir[key] then
                seen_dir[key] = true
                unique_dirs[#unique_dirs+1] = c.d
            end
        end

        -- Opposing forces on the same axis (right vs left, up vs down) → conflict.
        local pos_dx, neg_dx, pos_dy, neg_dy = false, false, false, false
        for _, d in ipairs(unique_dirs) do
            if d.dx > 0 then pos_dx = true elseif d.dx < 0 then neg_dx = true end
            if d.dy > 0 then pos_dy = true elseif d.dy < 0 then neg_dy = true end
        end
        if (pos_dx and neg_dx) or (pos_dy and neg_dy) then
            blocked = true
        else

        local net_dx, net_dy = 0, 0
        for _, d in ipairs(unique_dirs) do
            net_dx = net_dx + d.dx
            net_dy = net_dy + d.dy
        end

        local nx, ny = st.x + net_dx, st.y + net_dy
        local ok = not Sim.blocked(nx, ny, st.rows, st.cols, st.w, st.h, st.gaps)

        -- Diagonal moves: the two corner cells of the bounding box (outside both
        -- start and end footprints) must also be within bounds and gap-free.
        if ok and net_dx ~= 0 and net_dy ~= 0 then
            local cx1 = st.x + (net_dx > 0 and st.cols or -1)
            local cy1 = st.y + (net_dy > 0 and 0 or st.rows - 1)
            local cx2 = st.x + (net_dx > 0 and 0 or st.cols - 1)
            local cy2 = st.y + (net_dy > 0 and st.rows or -1)
            if cx1 < 1 or cx1 > st.w or cy1 < 1 or cy1 > st.h
               or cx2 < 1 or cx2 > st.w or cy2 < 1 or cy2 > st.h
               or (st.gaps and st.gaps[cy1] and st.gaps[cy1][cx1])
               or (st.gaps and st.gaps[cy2] and st.gaps[cy2][cx2]) then
                ok = false
            end
        end

        -- New matrix position must not overlap any pusher that is not part of this push.
        if ok then
            for _, q in ipairs(st.pushers) do
                local is_contact = false
                for _, c in ipairs(contacts) do
                    if c.p == q then is_contact = true; break end
                end
                if not is_contact and covers(nx, ny, st.rows, st.cols, q.x, q.y) then
                    ok = false; break
                end
            end
        end

        -- Contact pushers must not land on the same cell as each other.
        if ok and #contacts > 1 then
            local seen_landing = {}
            for _, c in ipairs(contacts) do
                local k = c.tx .. "," .. c.ty
                if seen_landing[k] then ok = false; break end
                seen_landing[k] = true
            end
        end

        if ok then
            st.x, st.y = nx, ny
            for _, c in ipairs(contacts) do
                c.p.x, c.p.y = c.tx, c.ty
            end
            moved = true
        else
            blocked = true
        end
        end -- end of non-opposing branch
    end

    -- Pass 3: non-contact pushers act sequentially in original order.
    -- They may not step into the matrix.
    for _, nc in ipairs(non_contacts) do
        local tx, ty = nc.tx, nc.ty
        local can_step = tx >= 1 and tx <= st.w and ty >= 1 and ty <= st.h
                         and not pusher_at(st.pushers, tx, ty, nc.p)
                         and not (st.gaps and st.gaps[ty] and st.gaps[ty][tx])
                         and not covers(st.x, st.y, st.rows, st.cols, tx, ty)
        if can_step then
            nc.p.x, nc.p.y = tx, ty
            moved = true
        else
            blocked = true
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
        local Matrix = require("lua/game/matrix_math")
        local addend = Matrix.new(rows, cols, tile.values)
        return matrix:add_matrix(addend)
    elseif op == "sub_matrix" then
        local rows = tile.tile_rows or 1
        local cols = tile.tile_cols or 1
        local Matrix = require("lua/game/matrix_math")
        local operand = Matrix.new(rows, cols, tile.values)
        return matrix:sub_matrix(operand)
    elseif op == "mul_matrix" then
        local rows = tile.tile_rows or 1
        local cols = tile.tile_cols or 1
        local Matrix = require("lua/game/matrix_math")
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
    elseif op == "add_rows" then
        local src = math.max(1, math.min(n, p.src or 1))
        local dst = math.max(1, math.min(n, p.dst or 2))
        if src == dst then return matrix end
        return matrix:add_rows(src, dst, p.scalar or 1)
    elseif op == "scale_col" then
        local c = math.max(1, math.min(matrix.cols, p.col or 1))
        return matrix:scale_col(c, p.scalar or 1)
    elseif op == "swap_cols" then
        local a = math.max(1, math.min(matrix.cols, p.col_a or 1))
        local b = math.max(1, math.min(matrix.cols, p.col_b or 2))
        return matrix:swap_cols(a, b)
    elseif op == "add_cols" then
        local src = math.max(1, math.min(matrix.cols, p.src or 1))
        local dst = math.max(1, math.min(matrix.cols, p.dst or 2))
        if src == dst then return matrix end
        return matrix:add_cols(src, dst, p.scalar or 1)
    elseif op == "set_col" then
        local col = p.col or 1
        local values = {}
        local tv = tile.values or {{}}
        for r = 1, tile.tile_rows or 1 do
            values[r] = (tv[r] and tv[r][1]) or 0
        end
        return matrix:set_col(col, values)
    elseif op == "rotate_90" then
        return matrix:rotate_90()
    elseif op == "flip_h" then
        return matrix:flip_h()
    elseif op == "flip_v" then
        return matrix:flip_v()
    elseif op == "abs" then
        return matrix:abs()
    end
    return matrix
end

return Sim
