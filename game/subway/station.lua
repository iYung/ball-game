local Station = {}
Station.__index = Station

-- data: one entry from network.stations
-- {id, name, lat, lon, lines=[], x=0, y=0}  (x,y set externally by map projection)
function Station.new(data)
    local self = setmetatable({}, Station)
    self.id    = data.id
    self.name  = data.name
    self.lat   = data.lat
    self.lon   = data.lon
    self.lines = data.lines or {}
    self.x     = data.x or 0
    self.y     = data.y or 0
    self.crowd = 0
    return self
end

function Station:add_crowd(n)
    self.crowd = math.max(0, self.crowd + n)
end

function Station:board_train(capacity)
    self.crowd = math.max(0, self.crowd - capacity * 0.7)
end

-- Returns r, g, b for the current crowd level.
-- Segments:
--   crowd 0    → green  (0.2, 0.8, 0.3)
--   crowd 500  → yellow (1.0, 0.85, 0.0)
--   crowd 2000 → red    (0.9, 0.2, 0.1)
function Station:get_color()
    local crowd = self.crowd
    local r, g, b

    if crowd <= 500 then
        local t = crowd / 500
        r = 0.2 + (1.0 - 0.2)  * t
        g = 0.8 + (0.85 - 0.8) * t
        b = 0.3 + (0.0  - 0.3) * t
    else
        local t = math.min((crowd - 500) / 1500, 1)
        r = 1.0 + (0.9 - 1.0) * t
        g = 0.85 + (0.2 - 0.85) * t
        b = 0.0 + (0.1 - 0.0) * t
    end

    return r, g, b
end

-- Draw the station — Mini Metro style.
-- A white ring always visible; inner fill grows from transparent to colored as crowd builds.
-- mx, my: mouse position in world/canvas coords for hover detection.
function Station:draw(mx, my)
    local outer_r = 8
    local inner_r = math.min(outer_r - 1, math.max(0, math.sqrt(self.crowd) * 0.18))
    local r, g, b = self:get_color()

    -- Outer soft glow when overcrowded
    if self.crowd > 300 then
        local glow_alpha = math.min(0.35, (self.crowd - 300) / 3000)
        love.graphics.setColor(r, g, b, glow_alpha)
        love.graphics.circle("fill", self.x, self.y, outer_r + 6)
    end

    -- Dark fill inside the ring (background)
    love.graphics.setColor(0.07, 0.08, 0.13, 1)
    love.graphics.circle("fill", self.x, self.y, outer_r - 1)

    -- Crowd fill: colored inner circle that grows with crowd
    if inner_r > 0.5 then
        love.graphics.setColor(r, g, b, 0.9)
        love.graphics.circle("fill", self.x, self.y, inner_r)
    end

    -- White ring outline — always visible
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", self.x, self.y, outer_r)

    -- Hover: station name
    local mouse_x = mx or love.mouse.getX()
    local mouse_y = my or love.mouse.getY()
    local dx = mouse_x - self.x
    local dy = mouse_y - self.y
    if dx * dx + dy * dy <= (outer_r + 6) * (outer_r + 6) then
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.push()
        love.graphics.translate(self.x + outer_r + 4, self.y - 6)
        love.graphics.scale(0.75, 0.75)
        love.graphics.print(self.name, 0, 0)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Station
