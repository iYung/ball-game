local Player = require("game/player")
local Level  = require("game/level")
local Input  = require("lua/core/input")
local Scene  = require("lua/core/scene")
local Sprite = require("lua/core/sprite")

local LevelScene = {}
LevelScene.__index = LevelScene

function LevelScene.new(level_id, entry, sm)
    local self = Scene.new(1280, 720)
    setmetatable(self, LevelScene)

    self.sm = sm
    self.level_id = level_id

    local level_def = require("game/levels/level_" .. level_id)

    self.level_def = level_def
    self.walls = Level.walls(level_def)

    local spawn = entry and Level.spawn(entry) or Level.default_spawn()
    self.player = Player.new(spawn.x, spawn.y, spawn.center_x, spawn.center_y, spawn.direction)

    self.input = Input.new({ space = { "space" } })

    return self
end

function LevelScene:on_enter()
    for _, rect in ipairs(self.walls) do
        local sprite = Sprite.new(rect.x, rect.y, rect.w, rect.h)
        sprite.color = { 0.5, 0.5, 0.55, 1 }
        self.drawer:add(sprite, 1)
    end

    self.drawer:add(self.player, 10)
end

function LevelScene:update(dt)
    if self._exited then return end

    self.input:update()
    local space_held = self.input:is_down("space")
    self.player:update(dt, space_held, self.walls)

    local p = self.player
    if p.x < 0 or p.x > 1280 or p.y < 0 or p.y > 720 then
        self._exited = true

        local next_entry = Level.mirrored_entry(self.level_def)
        local next_id = self.level_id + 1
        if next_id > 3 then
            next_id = 1
        end

        self.sm:switch(LevelScene.new(next_id, next_id == 1 and nil or next_entry, self.sm))
    end
end

function LevelScene:draw()
    Scene.draw(self)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Level " .. self.level_id, 16, 16)
    love.graphics.print("HOLD SPACE: grow orbit  /  RELEASE: shrink orbit", 16, 36)
end

return LevelScene
