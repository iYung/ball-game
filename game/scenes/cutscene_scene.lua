local Scene = require("lua/core/scene")

local W, H         = 1280, 720
local BOX_H        = 220
local BOX_Y        = H - BOX_H
local FADE_SPEED   = 1 / 0.4   -- alpha units per second
local PORTRAIT_W   = 160
local PORTRAIT_H   = 200
local PORTRAIT_X   = W - PORTRAIT_W - 20
local PORTRAIT_Y   = BOX_Y + (BOX_H - PORTRAIT_H) / 2

local CutsceneScene = setmetatable({}, { __index = Scene })
CutsceneScene.__index = CutsceneScene

-- Deterministic hue from a string name
local function _name_hue(name)
    if not name or name == "" then return 0.6 end
    local h = 0
    for i = 1, #name do h = (h * 31 + string.byte(name, i)) % 360 end
    return h / 360
end

local function _hsl_to_rgb(h, s, l)
    local function f(n)
        local k = (n + h * 12) % 12
        local a = s * math.min(l, 1 - l)
        return l - a * math.max(-1, math.min(k - 3, 9 - k, 1))
    end
    return f(0), f(8), f(4)
end

function CutsceneScene.new(world_num, next_scene, scene_manager)
    local base = Scene.new(W, H)
    local self = setmetatable(base, CutsceneScene)
    self._world_num      = world_num
    self._next_scene     = next_scene
    self._scene_manager  = scene_manager
    self._beats          = {}
    self._beat_idx       = 1
    self._fade_alpha     = 0
    self._portrait_cache = {}
    return self
end

function CutsceneScene:on_enter()
    self._font_speaker = love.graphics.newFont(16)
    self._font_text    = love.graphics.newFont(20)
    self._font_hint    = love.graphics.newFont(13)
    self._font_initial = love.graphics.newFont(48)

    local path = string.format("data/cutscenes/world_%d.lua", self._world_num)
    local chunk, err = love.filesystem.load(path)
    if not chunk then
        self._scene_manager:switch(self._next_scene)
        return
    end
    local ok, beats = pcall(chunk)
    if not ok or type(beats) ~= "table" or #beats == 0 then
        self._scene_manager:switch(self._next_scene)
        return
    end
    self._beats      = beats
    self._beat_idx   = 1
    self._fade_alpha = 0
end

function CutsceneScene:_advance()
    self._beat_idx = self._beat_idx + 1
    if self._beat_idx > #self._beats then
        self._scene_manager:switch(self._next_scene)
    else
        self._fade_alpha = 0
    end
end

function CutsceneScene:update(dt)
    if self._fade_alpha < 1 then
        self._fade_alpha = math.min(1, self._fade_alpha + dt * FADE_SPEED)
    end
end

function CutsceneScene:_get_portrait(name)
    if not name or name == "" then return nil end
    if self._portrait_cache[name] ~= nil then
        return self._portrait_cache[name]  -- may be false (failed)
    end
    local path = string.format("assets/portraits/%s.png", name)
    if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        self._portrait_cache[name] = ok and img or false
        return self._portrait_cache[name]
    end
    self._portrait_cache[name] = false
    return false
end

function CutsceneScene:_draw_portrait(name)
    local img = self:_get_portrait(name)
    if img then
        local iw, ih   = img:getDimensions()
        local sx       = PORTRAIT_W / iw
        local sy       = PORTRAIT_H / ih
        local s        = math.min(sx, sy)
        local dx       = PORTRAIT_X + (PORTRAIT_W  - iw * s) / 2
        local dy       = PORTRAIT_Y + (PORTRAIT_H - ih * s) / 2
        love.graphics.setColor(1, 1, 1, self._fade_alpha)
        love.graphics.draw(img, dx, dy, 0, s, s)
    else
        -- Code-drawn placeholder
        local hue  = _name_hue(name)
        local r, g, b = _hsl_to_rgb(hue, 0.45, 0.30)
        love.graphics.setColor(r, g, b, 0.85 * self._fade_alpha)
        love.graphics.rectangle("fill", PORTRAIT_X, PORTRAIT_Y, PORTRAIT_W, PORTRAIT_H, 10, 10)
        love.graphics.setColor(r * 1.6, g * 1.6, b * 1.6, self._fade_alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", PORTRAIT_X, PORTRAIT_Y, PORTRAIT_W, PORTRAIT_H, 10, 10)
        love.graphics.setLineWidth(1)

        if name and name ~= "" then
            love.graphics.setColor(1, 1, 1, 0.7 * self._fade_alpha)
            love.graphics.setFont(self._font_initial)
            love.graphics.printf(name:sub(1,1):upper(),
                PORTRAIT_X, PORTRAIT_Y + (PORTRAIT_H - self._font_initial:getHeight()) / 2,
                PORTRAIT_W, "center")
        end
    end
end

function CutsceneScene:draw()
    local beats = self._beats
    if #beats == 0 then return end
    local beat = beats[self._beat_idx]

    -- Background
    local bg = beat.bg or {0.05, 0.05, 0.10}
    love.graphics.setColor(bg[1], bg[2], bg[3], 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Beat indicator dots
    local n_beats  = #beats
    local dot_r    = 5
    local dot_gap  = 18
    local dots_w   = n_beats * dot_gap - (dot_gap - dot_r * 2)
    local dot_x0   = (W - dots_w) / 2
    local dot_y    = 20
    for i = 1, n_beats do
        if i == self._beat_idx then
            love.graphics.setColor(0.7, 0.85, 1.0, self._fade_alpha)
            love.graphics.circle("fill", dot_x0 + (i-1)*dot_gap + dot_r, dot_y + dot_r, dot_r)
        else
            love.graphics.setColor(0.4, 0.5, 0.65, 0.6)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", dot_x0 + (i-1)*dot_gap + dot_r, dot_y + dot_r, dot_r)
            love.graphics.setLineWidth(1)
        end
    end

    -- Text box panel
    love.graphics.setColor(0, 0, 0, 0.75 * self._fade_alpha)
    love.graphics.rectangle("fill", 0, BOX_Y, W, BOX_H)

    -- Portrait
    if beat.portrait then
        self:_draw_portrait(beat.portrait)
    end

    local text_right = beat.portrait and (PORTRAIT_X - 20) or (W - 24)
    local text_x     = 24
    local text_w     = text_right - text_x

    -- Speaker name
    if beat.speaker and beat.speaker ~= "" then
        love.graphics.setFont(self._font_speaker)
        love.graphics.setColor(0.6, 0.8, 1.0, self._fade_alpha)
        love.graphics.print(beat.speaker, text_x, BOX_Y + 14)
    end

    local speaker_h = (beat.speaker and beat.speaker ~= "") and (self._font_speaker:getHeight() + 8) or 0

    -- Dialogue text
    love.graphics.setFont(self._font_text)
    love.graphics.setColor(0.92, 0.92, 1.0, self._fade_alpha)
    love.graphics.printf(beat.text or "", text_x, BOX_Y + 14 + speaker_h, text_w, "left")

    -- Advance hint
    love.graphics.setFont(self._font_hint)
    love.graphics.setColor(0.4, 0.5, 0.6, 0.8 * self._fade_alpha)
    love.graphics.printf("[Enter / Click]  Advance   [Esc]  Skip",
        0, BOX_Y + BOX_H - self._font_hint:getHeight() - 10, W - 16, "right")

    love.graphics.setColor(1, 1, 1, 1)
end

function CutsceneScene:key_pressed(key)
    if key == "return" or key == "space" then
        self:_advance()
    elseif key == "escape" then
        self._scene_manager:switch(self._next_scene)
    end
end

function CutsceneScene:mouse_pressed(_, _, btn)
    if btn == 1 then self:_advance() end
end

function CutsceneScene:text_input(_) end

return CutsceneScene
