local Scene = require("lua/core/scene")

local W, H = 1280, 720

local StartScene = setmetatable({}, { __index = Scene })
StartScene.__index = StartScene

function StartScene.new(scene_manager)
    local self = Scene.new(W, H)
    setmetatable(self, StartScene)
    self._scene_manager = scene_manager
    return self
end

function StartScene:on_enter()
    self._font_title   = love.graphics.newFont(64)
    self._font_tagline = love.graphics.newFont(18)
    self._font_prompt  = love.graphics.newFont(16)
    self._time = 0
end

function StartScene:update(dt)
    self._time = self._time + dt
end

function StartScene:_advance()
    local LevelSelectScene = require("game/scenes/level_select_scene")
    self._scene_manager:switch(LevelSelectScene.new(self._scene_manager))
end

function StartScene:key_pressed(_)
    self:_advance()
end

function StartScene:mouse_pressed(_, _, _)
    self:_advance()
end

function StartScene:draw()
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Title
    love.graphics.setFont(self._font_title)
    love.graphics.setColor(0.95, 0.85, 0.5, 1)
    love.graphics.printf("MATRIX PUSH", 0, 220, W, "center")

    -- Tagline
    love.graphics.setFont(self._font_tagline)
    love.graphics.setColor(0.65, 0.60, 0.80, 1)
    love.graphics.printf("a matrix transformation puzzle", 0, 320, W, "center")

    -- Prompt (pulse)
    local alpha = 0.5 + 0.5 * math.sin(self._time * 3)
    love.graphics.setFont(self._font_prompt)
    love.graphics.setColor(0.60, 0.60, 0.70, alpha)
    love.graphics.printf("[Enter] or click to play", 0, 580, W, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

return StartScene
