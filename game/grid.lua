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

function Grid:set(x, y, tile)
    assert(self:in_bounds(x, y), string.format("Grid.set: (%d,%d) out of bounds", x, y))
    self.cells[y][x] = tile
end

function Grid:get(x, y)
    assert(self:in_bounds(x, y), string.format("Grid.get: (%d,%d) out of bounds", x, y))
    return self.cells[y][x]
end

function Grid:clear(x, y)
    if not self:in_bounds(x, y) then return end
    local tile = self.cells[y][x]
    if tile and tile.locked then return end
    self.cells[y][x] = nil
end

function Grid:clear_all()
    for y = 1, self.h do
        for x = 1, self.w do
            local tile = self.cells[y][x]
            if tile and not tile.locked then
                self.cells[y][x] = nil
            end
        end
    end
end

return Grid
