local Drawer = {}
Drawer.__index = Drawer

function Drawer.new()
    local self  = setmetatable({}, Drawer)
    self.layers = {}
    return self
end

function Drawer:add(sprite, priority)
    self.layers[#self.layers + 1] = { sprite = sprite, priority = priority or 0 }
    table.sort(self.layers, function(a, b) return a.priority < b.priority end)
end

function Drawer:draw()
    for _, entry in ipairs(self.layers) do
        entry.sprite:draw()
    end
end

function Drawer:clear()
    self.layers = {}
end

return Drawer
