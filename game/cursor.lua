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

local function apply_op(tile, matrix)
    if tile.kind ~= "op" then return matrix end
    local op = tile.op
    local p  = tile.params or {}
    if op == "transpose"  then return matrix:transpose()
    elseif op == "negate"     then return matrix:negate()
    elseif op == "scale_row"  then return matrix:scale_row(p.row, p.scalar)
    elseif op == "add_rows"   then return matrix:add_rows(p.src, p.dst, p.scalar)
    elseif op == "swap_rows"  then return matrix:swap_rows(p.row_a, p.row_b)
    elseif op == "scalar_mul" then return matrix:scalar_mul(p.scalar)
    end
    return matrix
end

function Cursor:step(matrix)
    -- Apply op at current cell (if any).
    local current_tile = self._grid:in_bounds(self.x, self.y) and self._grid:get(self.x, self.y)
    if current_tile then
        matrix = apply_op(current_tile, matrix)
    end

    -- Advance position.
    local d = DIRS[self.dir]
    local nx = self.x + d.dx
    local ny = self.y + d.dy

    -- Out-of-bounds check.
    if not self._grid:in_bounds(nx, ny) then
        return "out_of_bounds", matrix
    end

    self.x = nx
    self.y = ny

    -- Sink check.
    if self.x == self._sink_x and self.y == self._sink_y then
        return "sink", matrix
    end

    -- Update direction from arrow tile at new position.
    local new_tile = self._grid:get(self.x, self.y)
    if new_tile and new_tile.kind == "arrow" then
        self.dir = new_tile.dir
    end

    -- Loop detection (after direction update).
    local key = visited_key(self.x, self.y, self.dir)
    if self._visited[key] then
        return "loop", matrix
    end
    self._visited[key] = true

    return "ok", matrix
end

return Cursor
