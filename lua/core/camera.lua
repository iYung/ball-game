local Camera = {}
Camera.__index = Camera

function Camera.new(x, y, w, h)
    local self = setmetatable({}, Camera)
    self.x     = x or 0
    self.y     = y or 0
    self._w    = w or 1280
    self._h    = h or 720
    self.zoom  = 1.0
    return self
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(self._w / 2, self._h / 2)
    love.graphics.scale(self.zoom)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

-- lerp: 0 = instant follow, 1 = no movement
function Camera:follow(target, lerp)
    lerp   = lerp or 0
    local f = 1 - lerp
    self.x  = self.x + (target.x - self.x) * f
    self.y  = self.y + (target.y - self.y) * f
end


return Camera
