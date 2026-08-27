local Sprite = {}
Sprite.__index = Sprite

function Sprite.new(x, y, w, h)
    local self    = setmetatable({}, Sprite)
    self.x        = x or 0
    self.y        = y or 0
    self.width    = w or 32
    self.height   = h or 32
    self.scale_x  = 1
    self.scale_y  = 1
    self.visible  = true
    self.color    = {1, 1, 1, 1}
    self.shader   = nil
    self.image    = nil
    return self
end

function Sprite:draw()
    if not self.visible then return end
    love.graphics.push()
    local flip_ox = (self.scale_x < 0) and self.width or 0
    love.graphics.translate(self.x + flip_ox, self.y)
    love.graphics.scale(self.scale_x, self.scale_y)
    if self.shader then love.graphics.setShader(self.shader) end
    love.graphics.setColor(self.color)
    if self.image then
        local sx = self.width  / self.image:getWidth()
        local sy = self.height / self.image:getHeight()
        love.graphics.draw(self.image, 0, 0, 0, sx, sy)
    else
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
    if self.shader then love.graphics.setShader() end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function Sprite:update(dt) end

return Sprite
