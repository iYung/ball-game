local Grid = {}
Grid.__index = Grid

function Grid.new(w, h)
    local self = setmetatable({}, Grid)
    self.w = w
    self.h = h
    self.cells = {}
    for y = 1, h do
        self.cells[y] = {}
        for x = 1, w do
            self.cells[y][x] = nil
        end
    end
    return self
end

function Grid:in_bounds(x, y)
    return x >= 1 and x <= self.w and y >= 1 and y <= self.h
end

function Grid:in_bounds_multi(ax, ay, width)
    return self:in_bounds(ax, ay) and self:in_bounds(ax + width - 1, ay)
end

function Grid:in_bounds_multi_2d(ax, ay, width, height)
    return self:in_bounds(ax, ay) and self:in_bounds(ax + width - 1, ay + height - 1)
end

-- Returns true + anchor coords if (x,y) is a ref cell; false otherwise.
function Grid:is_ref(x, y)
    if not self:in_bounds(x, y) then return false, nil, nil end
    local cell = self.cells[y][x]
    if cell and cell.ref then return true, cell.ax, cell.ay end
    return false, nil, nil
end

-- Returns the anchor (ax, ay) for any cell of a multi-cell tile.
-- For nil cells or anchor cells, returns x, y unchanged.
function Grid:get_anchor(x, y)
    if not self:in_bounds(x, y) then return x, y end
    local cell = self.cells[y][x]
    if cell and cell.ref then
        return cell.ax, cell.ay
    end
    return x, y
end

-- set/get use assert so callers must bounds-check first.
function Grid:set(x, y, tile)
    assert(self:in_bounds(x, y), string.format("Grid.set: (%d,%d) out of bounds", x, y))
    self.cells[y][x] = tile
end

-- Place a 2D multi-cell tile. Anchor at (ax,ay); ref cells fill the width×height region.
function Grid:set_multi_2d(ax, ay, tile, width, height)
    assert(self:in_bounds_multi_2d(ax, ay, width, height),
        string.format("Grid.set_multi_2d: (%d,%d) width %d height %d out of bounds", ax, ay, width, height))
    self.cells[ay][ax] = tile
    for dy = 0, height - 1 do
        for dx = 0, width - 1 do
            if not (dx == 0 and dy == 0) then
                self.cells[ay + dy][ax + dx] = { ref = true, ax = ax, ay = ay }
            end
        end
    end
end

-- Place a multi-cell tile. Anchor at (ax,ay); ref cells at (ax+1,ay)..(ax+w-1,ay).
function Grid:set_multi(ax, ay, tile, width)
    assert(self:in_bounds_multi(ax, ay, width),
        string.format("Grid.set_multi: (%d,%d) width %d out of bounds", ax, ay, width))
    self.cells[ay][ax] = tile
    for i = 1, width - 1 do
        self.cells[ay][ax + i] = { ref = true, ax = ax, ay = ay }
    end
end

-- Transparently resolves ref cells so callers always receive the anchor tile.
function Grid:get(x, y)
    assert(self:in_bounds(x, y), string.format("Grid.get: (%d,%d) out of bounds", x, y))
    local cell = self.cells[y][x]
    if cell and cell.ref then
        return self.cells[cell.ay][cell.ax]
    end
    return cell
end

-- Clear any cell of a multi-cell tile: resolves to anchor, then wipes all cells it spans.
function Grid:clear(x, y)
    if not self:in_bounds(x, y) then return end
    local raw = self.cells[y][x]
    if raw == nil then return end

    -- Resolve to anchor
    local ax, ay
    if raw.ref then
        ax, ay = raw.ax, raw.ay
    else
        ax, ay = x, y
    end

    local tile = self.cells[ay][ax]
    if tile == nil or tile.locked then return end

    -- Determine width from the tile's stored width, or scan right for refs
    local width = tile.width or 1
    if width == 1 then
        -- Scan right to find any trailing ref cells
        local nx = ax + 1
        local c = self:in_bounds(nx, ay) and self.cells[ay][nx]
        while c and c.ref and c.ax == ax and c.ay == ay do
            width = nx - ax + 1
            nx = nx + 1
            c = self:in_bounds(nx, ay) and self.cells[ay][nx]
        end
    end

    local height = tile.height or 1

    for dy = 0, height - 1 do
        for dx = 0, width - 1 do
            if self:in_bounds(ax + dx, ay + dy) then
                self.cells[ay + dy][ax + dx] = nil
            end
        end
    end
end

function Grid:clear_all()
    for y = 1, self.h do
        for x = 1, self.w do
            local tile = self.cells[y][x]
            -- Skip ref cells (the anchor clear handles them) and locked tiles
            if tile and not tile.ref and not tile.locked then
                -- Clear via clear() to also wipe any ref cells to the right
                self:clear(x, y)
            end
        end
    end
end

return Grid
