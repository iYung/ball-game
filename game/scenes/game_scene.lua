local Scene  = require("lua/core/scene")
local Sprite = require("lua/core/sprite")
local Timer  = require("lua/core/timer")
local Player = require("game/player")

local GameScene = {}
GameScene.__index = GameScene

function GameScene.new()
    local self = Scene.new(1280, 720)
    setmetatable(self, GameScene)
    return self
end

function GameScene:on_enter()
    self.player = Player.new(-16, 170)
    self.drawer:add(self.player, 10)

    self.ground = Sprite.new(-640, 220, 1600, 30)
    self.ground.color = { 0.25, 0.65, 0.25, 1 }
    self.drawer:add(self.ground, 1)

    self.blink_timer = Timer.new(0.5)
    self.coins = {}
    for i = 1, 7 do
        local coin = Sprite.new(i * 140 - 560, 193, 18, 18)
        coin.color = { 1, 0.85, 0.1, 1 }
        self.drawer:add(coin, 5)
        table.insert(self.coins, coin)
    end
end

function GameScene:update(dt)
    self.player:update(dt)
    self.camera:follow(self.player:centre(), 0.85)

    if self.blink_timer:update(dt) then
        for _, coin in ipairs(self.coins) do
            coin.visible = not coin.visible
        end
    end
end

function GameScene:draw()
    Scene.draw(self)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("WASD / Arrow keys to move   ESC to quit", 16, 16)
    local c = self.player:centre()
    love.graphics.print(string.format("player (%.0f, %.0f)", c.x, c.y), 16, 36)
end

return GameScene
