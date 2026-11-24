local Scene = require("lua/core/scene")
local UI    = require("lua/core/ui")

local W, H = 1280, 720

local StartScene = setmetatable({}, { __index = Scene })
StartScene.__index = StartScene

function StartScene.new(scene_manager, settings_state)
    local self = Scene.new(W, H)
    setmetatable(self, StartScene)
    self._scene_manager  = scene_manager
    self._settings_state = settings_state
    return self
end

function StartScene:on_enter()
    self._font_title   = love.graphics.newFont(64)
    self._font_tagline = love.graphics.newFont(18)
    self._font_prompt  = love.graphics.newFont(16)
    self._font_debug   = love.graphics.newFont(14)
    self._time = 0
    self._play_rect    = { x = W / 2 - 120, y = 572, w = 240, h = 32 }
    self._unlock_rect  = { x = W / 2 - 80, y = 625, w = 160, h = 22 }
    local Sound = require("lua/core/sound")
    if not Sound.is_music_playing("menu") then Sound.play_music("menu") end
end

-- UI element registry (see docs/design/ui-tests.md). Fresh table each call.
function StartScene:ui_elements()
    local p, u = self._play_rect, self._unlock_rect
    return {
        { id = "start:play", label = "Play", kind = "button",
          rect = { x = p.x, y = p.y, w = p.w, h = p.h }, enabled = true },
        { id = "start:unlock_all", label = "Unlock All", kind = "button",
          rect = { x = u.x, y = u.y, w = u.w, h = u.h }, enabled = true },
    }
end

function StartScene:update(dt)
    self._time = self._time + dt
end

function StartScene:_advance()
    local LevelSelectScene = require("lua/game/scenes/level_select_scene")
    local next_scene = LevelSelectScene.new(self._scene_manager, self._settings_state)

    local Progress = require("lua/game/progress")
    if not Progress.is_cutscene_seen(0) then
        Progress.mark_cutscene_seen(0)
        local CutsceneScene = require("lua/game/scenes/cutscene_scene")
        self._scene_manager:switch(CutsceneScene.new(0, next_scene, self._scene_manager))
        return
    end

    self._scene_manager:switch(next_scene)
end

function StartScene:_unlock_all()
    local Progress = require("lua/game/progress")
    Progress.unlock_all()
    self:_advance()
end

function StartScene:key_pressed(key)
    if key == "d" then
        self:_unlock_all()
        return
    end
    self:_advance()
end

function StartScene:mouse_pressed(mx, my, _)
    local e = UI.element_at(self:ui_elements(), mx, my)
    if e and e.id == "start:unlock_all" then
        self:_unlock_all()
        return
    end
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

    -- Debug: unlock all
    love.graphics.setFont(self._font_debug)
    love.graphics.setColor(0.35, 0.32, 0.42, 0.7)
    love.graphics.printf("(D) Unlock All", 0, 630, W, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

return StartScene
