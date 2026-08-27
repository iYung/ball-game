local SpriteSet = {}
SpriteSet.__index = function(t, k)
    if k == "width" or k == "height" then
        local active = rawget(t, "sprites")[rawget(t, "current")]
        return active and active[k] or 0
    end
    return SpriteSet[k]
end

function SpriteSet.new()
    local self    = setmetatable({}, SpriteSet)
    self.sprites  = {}
    self.current  = nil
    self.x        = 0
    self.y        = 0
    self.scale_x  = 1
    self.scale_y  = 1
    self.visible  = true
    return self
end

function SpriteSet:add(name, sprite)
    self.sprites[name] = sprite
    if not self.current then
        self.current = name
    end
end

function SpriteSet:set(name)
    self.current = name
end

function SpriteSet:_active()
    return self.sprites[self.current]
end

function SpriteSet:draw()
    if not self.visible then return end
    local s = self:_active()
    if not s then return end
    s.x       = self.x
    s.y       = self.y
    s.scale_x = self.scale_x
    s.scale_y = self.scale_y
    s:draw()
end

function SpriteSet:update(dt)
    local s = self:_active()
    if s then s:update(dt) end
end

return SpriteSet
