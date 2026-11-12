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

-- Draw the station.
-- mx, my: optional mouse position already in world/canvas coords.
-- If omitted, love.mouse.getPosition() is used (screen coords — only
-- correct when no camera transform is applied).
function Station:draw(mx, my)
    local radius = math.max(4, math.min(40, 4 + math.sqrt(self.crowd) * 0.15))
    local r, g, b = self:get_color()

    -- Filled circle
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("fill", self.x, self.y, radius)

    -- Dim white outline
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.circle("line", self.x, self.y, radius)

    -- Hover: draw station name as small text above the circle
    local mouse_x, mouse_y
    if mx ~= nil and my ~= nil then
        mouse_x, mouse_y = mx, my
    else
        mouse_x, mouse_y = love.mouse.getPosition()
    end

    local dx = mouse_x - self.x
    local dy = mouse_y - self.y
    if dx * dx + dy * dy <= radius * radius then
        love.graphics.setColor(1, 1, 1, 0.9)
        -- Push a scale transform so the text renders small regardless of camera zoom
        love.graphics.push()
        local tx = self.x - radius
        local ty = self.y - radius - 10
        love.graphics.translate(tx, ty)
        love.graphics.scale(0.7, 0.7)
        love.graphics.print(self.name, 0, 0)
        love.graphics.pop()
    end

    -- Reset colour
    love.graphics.setColor(1, 1, 1, 1)
end

return Station
