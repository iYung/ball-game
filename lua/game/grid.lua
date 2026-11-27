local Ops = require("lua/game/ops")

local Grid = {}
Grid.__index = Grid

local function is_two_cell(tile)
    return tile ~= nil and tile.kind == "op" and Ops.is_two_cell(tile.op)
end

local function facing_of(tile)
    return tile.params and tile.params.facing or "right"
end

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

-- True when every cell the tile would occupy with its anchor at (x,y) is in
-- bounds and empty: one cell, or two for a two-cell tile.
function Grid:fits(x, y, tile)
    if not (self:in_bounds(x, y) and self.cells[y][x] == nil) then return false end
    if not is_two_cell(tile) then return true end
    local px, py = Ops.partner(x, y, facing_of(tile))
    return self:in_bounds(px, py) and self.cells[py][px] == nil
end

-- Writes a one- or two-cell tile with its anchor at (x,y). A two-cell tile's
-- partner cell becomes a ref cell. Callers check fits first.
function Grid:put(x, y, tile)
    if not is_two_cell(tile) then
        self:set(x, y, tile)
        return
    end
    local px, py = Ops.partner(x, y, facing_of(tile))
    assert(self:in_bounds(px, py), string.format("Grid.put: (%d,%d) out of bounds", px, py))
    self:set(x, y, tile)
    self.cells[py][px] = { ref = true, ax = x, ay = y }
end

-- Turns the two-cell tile covering (x,y) to the next clockwise facing whose
-- partner cell is in bounds and empty. Returns false, changing nothing, when
-- there is no such tile or facing. Locked and fixed are the caller's concern.
function Grid:rotate(x, y)
    if not self:in_bounds(x, y) then return false end
    local ax, ay = self:get_anchor(x, y)
    local tile = self.cells[ay][ax]
    if not is_two_cell(tile) then return false end
    local old = facing_of(tile)
    local facing = Ops.next_facing(old)
    while facing ~= old do
        local px, py = Ops.partner(ax, ay, facing)
        if self:in_bounds(px, py) and self.cells[py][px] == nil then
            local ox, oy = Ops.partner(ax, ay, old)
            self.cells[oy][ox] = nil
            self.cells[py][px] = { ref = true, ax = ax, ay = ay }
            tile.params = tile.params or {}
            tile.params.facing = facing
            return true
        end
        facing = Ops.next_facing(facing)
    end
    return false
end

-- Every two-cell tile as { x, y, rx, ry, tile } (left-operand cell, then
-- right-operand cell), in reading order of the left-operand cell.
function Grid:two_cell_tiles()
    local list = {}
    for y = 1, self.h do
        for x = 1, self.w do
            local tile = self.cells[y][x]
            if is_two_cell(tile) then
                local rx, ry = Ops.partner(x, y, facing_of(tile))
                list[#list + 1] = { x = x, y = y, rx = rx, ry = ry, tile = tile }
            end
        end
    end
    return list
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

    -- A two-cell tile's partner can be on any side of the anchor.
    if is_two_cell(tile) then
        local px, py = Ops.partner(ax, ay, facing_of(tile))
        self.cells[ay][ax] = nil
        self.cells[py][px] = nil
        return
    end

    -- Determine width from the tile's stored width, or scan right for refs
    local width = tile.width or 1
    if width == 1 then
        -- Scan right to find any trailing ref cells
        local nx = ax + 1
        while self:in_bounds(nx, ay) do
            local c = self.cells[ay][nx]
            if not (c and c.ref and c.ax == ax and c.ay == ay) then break end
            width = nx - ax + 1
            nx = nx + 1
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
