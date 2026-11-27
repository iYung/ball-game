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

-- True if pusher p may step into (tx, ty) as far as the grid, gaps and other pushers go.
-- Matrices are judged by the caller.
local function can_step(st, p, tx, ty)
    return tx >= 1 and tx <= st.w and ty >= 1 and ty <= st.h
           and not pusher_at(st.pushers, tx, ty, p)
           and not (st.gaps and st.gaps[ty] and st.gaps[ty][tx])
end

-- Combined move of one matrix from its contacts: the same direction counts once and
-- perpendicular ones add up to a diagonal. Returns dx, dy, or nil when two oppose.
local function net_push(contacts)
    local pos_dx, neg_dx, pos_dy, neg_dy = false, false, false, false
    for _, c in ipairs(contacts) do
        local d = c.d
        if d.dx > 0 then pos_dx = true elseif d.dx < 0 then neg_dx = true end
        if d.dy > 0 then pos_dy = true elseif d.dy < 0 then neg_dy = true end
    end
    if (pos_dx and neg_dx) or (pos_dy and neg_dy) then return nil end
    return (pos_dx and 1 or 0) - (neg_dx and 1 or 0),
           (pos_dy and 1 or 0) - (neg_dy and 1 or 0)
end

-- The two corner cells of the bounding box of a diagonal move (outside both the start and
-- end footprints) of matrix m = { x, y, rows, cols }.
local function corner_cells(m, dx, dy)
    return {
        { x = m.x + (dx > 0 and m.cols or -1), y = m.y + (dy > 0 and 0 or m.rows - 1) },
        { x = m.x + (dx > 0 and 0 or m.cols - 1), y = m.y + (dy > 0 and m.rows or -1) },
    }
end

-- True if the grid and gaps allow matrix m to move by (dx, dy). A diagonal move also needs
-- both corner cells in bounds and gap-free.
local function move_fits(st, m, dx, dy)
    if Sim.blocked(m.x + dx, m.y + dy, m.rows, m.cols, st.w, st.h, st.gaps) then
        return false
    end
    if dx ~= 0 and dy ~= 0 then
        for _, c in ipairs(corner_cells(m, dx, dy)) do
            if Sim.blocked(c.x, c.y, 1, 1, st.w, st.h, st.gaps) then return false end
        end
    end
    return true
end

-- True if no two contact pushers land on the same cell.
local function distinct_landings(contacts)
    local seen = {}
    for _, c in ipairs(contacts) do
        local k = c.tx .. "," .. c.ty
        if seen[k] then return false end
        seen[k] = true
    end
    return true
end

-- True if the footprints of matrices a and b share a cell.
local function overlaps(a, b)
    return a.x <= b.x + b.cols - 1 and b.x <= a.x + a.cols - 1
       and a.y <= b.y + b.rows - 1 and b.y <= a.y + a.rows - 1
end

-- True if the two moves make the matrices collide: they end overlapping, they exchange
-- places, or one moving diagonally has a corner cell where the other ends up.
local function matrices_collide(a, b)
    if overlaps(a.to, b.to) then return true end
    if a.moved and b.moved and overlaps(a.to, b.from) and overlaps(b.to, a.from) then
        return true
    end
    for _, pair in ipairs({ { a, b }, { b, a } }) do
        local m, other = pair[1], pair[2].to
        if m.dx ~= 0 and m.dy ~= 0 then
            for _, c in ipairs(corner_cells(m.from, m.dx, m.dy)) do
                if covers(other.x, other.y, other.rows, other.cols, c.x, c.y) then
                    return true
                end
            end
        end
    end
    return false
end

-- Physics of one tick with two matrices. Pushers only change when the whole tick succeeds;
-- the matrices are written to st and st.second at the end. Returns moved, blocked, collided.
local function advance_two(st)
    local second = st.second
    local bodies = {
        { from = { x = st.x, y = st.y, rows = st.rows, cols = st.cols }, contacts = {} },
        { from = { x = second.x, y = second.y, rows = second.rows, cols = second.cols },
          contacts = {} },
    }

    -- Classify from start positions: a contact pushes the matrix it steps into.
    local all_contacts, non_contacts = {}, {}
    local pushes = {}   -- contact pusher -> the body it pushes
    for _, p in ipairs(st.pushers) do
        local d = Sim.DIRS[p.dir or "stop"]
        if d then
            local tx, ty = p.x + d.dx, p.y + d.dy
            local target
            if can_step(st, p, tx, ty) then
                for _, body in ipairs(bodies) do
                    local m = body.from
                    if covers(m.x, m.y, m.rows, m.cols, tx, ty) then target = body end
                end
            end
            if target then
                local c = { p=p, d=d, tx=tx, ty=ty }
                target.contacts[#target.contacts+1] = c
                all_contacts[#all_contacts+1] = c
                pushes[p] = target
            else
                non_contacts[#non_contacts+1] = { p=p, tx=tx, ty=ty }
            end
        end
    end

    -- Where each matrix wants to go. Nothing has changed yet, so failures just return.
    for _, body in ipairs(bodies) do
        local m = body.from
        local dx, dy = net_push(body.contacts)
        if not dx then return false, true, false end
        body.moved = #body.contacts > 0
        if body.moved and not move_fits(st, m, dx, dy) then return false, true, false end
        body.dx, body.dy = dx, dy
        body.to = { x = m.x + dx, y = m.y + dy, rows = m.rows, cols = m.cols }
    end
    if not distinct_landings(all_contacts) then return false, true, false end

    local snap = {}
    for i, p in ipairs(st.pushers) do snap[i] = { p.x, p.y } end
    local function rollback(collided)
        for i, p in ipairs(st.pushers) do p.x, p.y = snap[i][1], snap[i][2] end
        return false, true, collided
    end

    local moved = #all_contacts > 0
    for _, c in ipairs(all_contacts) do c.p.x, c.p.y = c.tx, c.ty end

    -- The other pushers act in array order and may not step into either final footprint.
    for _, nc in ipairs(non_contacts) do
        local tx, ty = nc.tx, nc.ty
        local free = can_step(st, nc.p, tx, ty)
        for _, body in ipairs(bodies) do
            local m = body.to
            if covers(m.x, m.y, m.rows, m.cols, tx, ty) then free = false end
        end
        if not free then return rollback(false) end
        nc.p.x, nc.p.y = tx, ty
        moved = true
    end

    -- No pusher may end inside a matrix that moved unless it pushed that matrix. When the
    -- matrices collide, the other matrix's contacts do not count: they ride into the overlap.
    local collided = matrices_collide(bodies[1], bodies[2])
    for _, body in ipairs(bodies) do
        if body.moved then
            local m = body.to
            for _, q in ipairs(st.pushers) do
                local by = pushes[q]
                if by ~= body and not (collided and by)
                   and covers(m.x, m.y, m.rows, m.cols, q.x, q.y) then
                    return rollback(false)
                end
            end
        end
    end
    if collided then return rollback(true) end

    st.x, st.y         = bodies[1].to.x, bodies[1].to.y
    second.x, second.y = bodies[2].to.x, bodies[2].to.y
    return moved, false, false
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
-- Mutates st.tick, st.x/st.y and each pusher's x/y. Returns moved (bool: anything moved),
-- blocked (bool: something could not act) and collided (bool; implies blocked).
-- Optional st.second = { x, y, rows, cols } is a second matrix (its x/y are mutated too).
-- Each contact pushes only the matrix it steps into, both matrices move at once and never
-- push each other, and any blocked or collided tick leaves both matrices and all pushers
-- where they were. collided means the matrices would overlap, exchange places or clip each
-- other diagonally; wall, gap, edge, opposing and pusher problems are reported first.
function Sim.advance(st, commands)
    st.tick = st.tick + 1
    for _, c in ipairs(commands or {}) do
        for _, p in ipairs(st.pushers) do
            if p.id == c.pusher then p.dir = c.cmd end
        end
    end
    if st.second then return advance_two(st) end
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
            if can_step(st, p, tx, ty) and covers(st.x, st.y, st.rows, st.cols, tx, ty) then
                contacts[#contacts+1] = { p=p, d=d, tx=tx, ty=ty }
            else
                non_contacts[#non_contacts+1] = { p=p, tx=tx, ty=ty }
            end
        end
    end

    -- Pass 2: aggregate contact forces (deduplicate same direction), attempt one combined move.
    if #contacts > 0 then
        -- Opposing forces on the same axis (right vs left, up vs down) → conflict.
        local net_dx, net_dy = net_push(contacts)
        if not net_dx then
            blocked = true
        else

        local nx, ny = st.x + net_dx, st.y + net_dy
        local ok = move_fits(st, st, net_dx, net_dy) and distinct_landings(contacts)

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
        if can_step(st, nc.p, tx, ty)
           and not covers(st.x, st.y, st.rows, st.cols, tx, ty) then
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

    return moved, blocked, false
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
