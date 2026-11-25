local Ops = require("lua/game/ops")

local Sim = {}

Sim.DIRS = {
    up    = { dx =  0, dy = -1 },
    down  = { dx =  0, dy =  1 },
    left  = { dx = -1, dy =  0 },
    right = { dx =  1, dy =  0 },
}

local function covers(x, y, rows, cols, cx, cy)
    return cx >= x and cx <= x + cols - 1 and cy >= y and cy <= y + rows - 1
end

-- Pushers are lettered A.. by id, 1..MAX_PUSHERS.
Sim.MAX_PUSHERS = 8

-- Lowest id not in the `used` set, or nil when all are taken.
function Sim.free_pusher_id(used)
    for id = 1, Sim.MAX_PUSHERS do
        if not used[id] then return id end
    end
end

-- Ids for the pusher entries of a puzzle definition, as a map entry -> id. Valid ids are
-- kept (first one wins); missing, repeated or invalid ones get the lowest free id in list
-- order. Entries past MAX_PUSHERS get none.
function Sim.assign_pusher_ids(entries)
    local ids, used = {}, {}
    for _, t in ipairs(entries) do
        local id = t.id
        if t.kind == "pusher" and type(id) == "number" and id % 1 == 0
           and id >= 1 and id <= Sim.MAX_PUSHERS and not used[id] then
            ids[t], used[id] = id, true
        end
    end
    for _, t in ipairs(entries) do
        if t.kind == "pusher" and not ids[t] then
            local id = Sim.free_pusher_id(used)
            if id then ids[t], used[id] = id, true end
        end
    end
    return ids
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

-- Run one tick. st: { x, y, rows, cols, w, h, pushers, tick } where x,y is the matrix
-- anchor and pushers is an array of { id, x, y, dir }; dir is the pusher's persistent
-- direction ("up"|"down"|"left"|"right"|"stop"|nil; nil/"stop" = not moving).
-- commands is this tick's list { {pusher=id, cmd=cmd}, ... } (may be nil/empty); each one
-- sets the dir of the pusher with that id before the physics runs. dir is never cleared by
-- physics: a blocked pusher keeps its dir and tries again next tick.
-- Pushers act one at a time in array order, each stepping one cell in its dir:
--   * off the grid, or into another pusher's cell: the pusher stays put
--   * into a matrix cell: the matrix is shoved one cell the same way; if that would take it
--     off the grid or onto another pusher, nothing moves
-- Mutates st.tick, st.x/st.y and each pusher's x/y. Returns moved (bool): anything moved.
function Sim.advance(st, commands)
    st.tick = st.tick + 1
    for _, c in ipairs(commands or {}) do
        for _, p in ipairs(st.pushers) do
            if p.id == c.pusher then p.dir = c.cmd end
        end
    end
    local moved   = false
    local blocked = false
    local pushed  = false   -- the matrix + contact pushers were moved this tick

    -- Snapshot so a tick whose matrix push turns out blocked can be rolled back: no pusher
    -- may be left half-way inside the matrix.
    local snap_x, snap_y, snap_pos = st.x, st.y, {}
    for i, p in ipairs(st.pushers) do snap_pos[i] = { p.x, p.y } end

    -- Pass 1: classify each commanded pusher.
    -- contact: its step lands on a matrix cell (using start-of-tick positions).
    -- non_contact: everything else (wall, gap, another pusher, or not touching the matrix).
    local contacts     = {}
    local non_contacts = {}
    for _, p in ipairs(st.pushers) do
        local d = Sim.DIRS[p.dir or "stop"]
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
            pushed = true
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

    -- Pass 4: when the matrix moved, no pusher outside the push may end the tick inside it.
    -- Checked on final positions, so a pusher stepping out of the way as the matrix arrives
    -- is fine; one left (or pushed) inside it is a collision.
    if pushed then
        for _, q in ipairs(st.pushers) do
            local is_contact = false
            for _, c in ipairs(contacts) do
                if c.p == q then is_contact = true; break end
            end
            if not is_contact and covers(st.x, st.y, st.rows, st.cols, q.x, q.y) then
                blocked = true; break
            end
        end
    end

    if blocked and pushed then
        st.x, st.y = snap_x, snap_y
        for i, p in ipairs(st.pushers) do p.x, p.y = snap_pos[i][1], snap_pos[i][2] end
        moved = false
    end

    return moved, blocked
end

-- Applies an op tile to a matrix. Missing params take the op's defaults; non-op tiles and
-- unknown ops return the same matrix object.
function Sim.apply_op(tile, matrix)
    if tile.kind ~= "op" then return matrix end
    local op = tile.op
    local p  = Ops.params(op, tile.params)

    if op == "scalar_mul" then
        return matrix:scalar_mul(p.scalar)
    elseif op == "scalar_add" then
        return matrix:scalar_add(p.scalar)
    elseif op == "scalar_sub" then
        return matrix:scalar_sub(p.scalar)
    elseif op == "edge_scale" then
        return matrix:edge_scale(p.edge, p.scalar)
    elseif op == "edge_add" then
        return matrix:edge_add(p.edge, p.scalar)
    elseif op == "edge_sub" then
        return matrix:edge_sub(p.edge, p.scalar)
    elseif op == "transpose" then
        return matrix:transpose()
    elseif op == "rotate_90" then
        return matrix:rotate_90()
    elseif op == "flip_h" then
        return matrix:flip_h()
    elseif op == "flip_v" then
        return matrix:flip_v()
    end
    return matrix
end

return Sim
