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

    -- The camera defaults to centering world (0,0) on screen; since the room
    -- occupies world (0,0)-(1280,720) with a top-left origin, park the camera
    -- at the room's center so world coords map 1:1 onto the screen.
    self.camera.x = 640
    self.camera.y = 360

    self.sm = sm
    self.level_id = level_id

    local level_def = require("game/levels/level_" .. level_id)

    self.level_def = level_def
    self.walls = Level.walls(level_def, entry)

    local spawn = entry and Level.spawn(entry) or Level.default_spawn()
    self.player = Player.new(spawn.x, spawn.y, spawn.heading)

    self.input = Input.new({ flip_left = { "a" }, flip_right = { "d" } })

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
    local flip_left  = self.input:pressed("flip_left")
    local flip_right = self.input:pressed("flip_right")
    self.player:update(dt, flip_left, flip_right, self.walls)

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
    love.graphics.print("A / D: flip tail left / right  -  alternate sides to swim forward", 16, 36)
end

return LevelScene
