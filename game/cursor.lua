local Cursor = {}
Cursor.__index = Cursor

local DIRS = {
    right = { dx =  1, dy =  0 },
    left  = { dx = -1, dy =  0 },
    up    = { dx =  0, dy = -1 },
    down  = { dx =  0, dy =  1 },
}

function Cursor.new(grid, sx, sy, start_dir, sink_x, sink_y)
    local self = setmetatable({}, Cursor)
    self._grid      = grid
    self._sx        = sx
    self._sy        = sy
    self._start_dir = start_dir
    self._sink_x    = sink_x
    self._sink_y    = sink_y
    self:reset()
    return self
end

function Cursor:reset()
    self.x   = self._sx
    self.y   = self._sy
    self.dir = self._start_dir
    self._visited = {}
end

local function visited_key(x, y, dir)
    return x .. "," .. y .. "," .. dir
end

-- Exported so matrix_scene can apply ops from footprint cells.
function Cursor.apply_op(tile, matrix)
    if tile.kind ~= "op" then return matrix end
    local op = tile.op
    local p  = tile.params or {}
    local n  = matrix.rows  -- clamp row indices to actual matrix size

    if op == "transpose" then
        return matrix:transpose()
    elseif op == "negate" then
        return matrix:negate()
    elseif op == "scale_row" then
        local r = math.max(1, math.min(n, p.row    or 1))
        local s = p.scalar or 1
        return matrix:scale_row(r, s)
    elseif op == "add_rows" then
        local src = math.max(1, math.min(n, p.src   or 1))
        local dst = math.max(1, math.min(n, p.dst   or 2))
        local s   = p.scalar or 1
        if src == dst then return matrix end  -- would be a no-op / NaN risk
        return matrix:add_rows(src, dst, s)
    elseif op == "swap_rows" then
        local a = math.max(1, math.min(n, p.row_a or 1))
        local b = math.max(1, math.min(n, p.row_b or 2))
        return matrix:swap_rows(a, b)
    elseif op == "scalar_mul" then
        local s = p.scalar or 1
        return matrix:scalar_mul(s)
    end
    return matrix
end

-- Advance the anchor one step. Picks up arrow direction at the new cell.
-- Returns "ok" | "sink" | "loop" | "out_of_bounds". Does NOT apply any op.
function Cursor:move()
    local d  = DIRS[self.dir]
    local nx = self.x + d.dx
    local ny = self.y + d.dy

    if not self._grid:in_bounds(nx, ny) then
        return "out_of_bounds"
    end

    self.x = nx
    self.y = ny

    if self.x == self._sink_x and self.y == self._sink_y then
        return "sink"
    end

    local tile = self._grid:get(self.x, self.y)
    if tile and tile.kind == "arrow" then
        self.dir = tile.dir
    end

    local key = visited_key(self.x, self.y, self.dir)
    if self._visited[key] then
        return "loop"
    end
    self._visited[key] = true

    return "ok"
end

return Cursor
