local Sprite = require("lua/core/sprite")
local Input  = require("lua/core/input")

local SPEED = 200

local Player = {}
Player.__index = Player

function Player.new(x, y)
    local self        = setmetatable({}, Player)
    self.sprite       = Sprite.new(x, y, 32, 48)
    self.sprite.image = love.graphics.newImage("assets/player.png")
    self.input        = Input.new({
        up    = { "w", "up" },
        down  = { "s", "down" },
        left  = { "a", "left" },
        right = { "d", "right" },
    })
    return self
end

function Player:update(dt)
    self.input:update()
    local s = self.sprite
    if self.input:is_down("left")  then s.x = s.x - SPEED * dt end
    if self.input:is_down("right") then s.x = s.x + SPEED * dt end
    if self.input:is_down("up")    then s.y = s.y - SPEED * dt end
    if self.input:is_down("down")  then s.y = s.y + SPEED * dt end
end

-- Centre point used for camera tracking
function Player:centre()
    return { x = self.sprite.x + 16, y = self.sprite.y + 24 }
end

function Player:draw()
    self.sprite:draw()
end

return Player
