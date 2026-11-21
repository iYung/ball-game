local UI           = require("lua/core/ui")
local Save         = require("lua/core/save")
local SettingsState = require("lua/game/settings_state")

local W, H = 1280, 720

local PANEL_W = 400
local PANEL_H = 300
local PANEL_X = (W - PANEL_W) / 2  -- 440
local PANEL_Y = (H - PANEL_H) / 2  -- 210

-- UI element rects (verified non-overlapping, all within screen bounds)
local R_SFX_DEC   = { x = 510, y = 250, w = 30, h = 30 }
local R_SFX_INC   = { x = 640, y = 250, w = 30, h = 30 }
local R_MUSIC_DEC = { x = 510, y = 298, w = 30, h = 30 }
local R_MUSIC_INC = { x = 640, y = 298, w = 30, h = 30 }
local R_RESUME    = { x = 490, y = 368, w = 200, h = 36 }
local R_EXIT      = { x = 490, y = 418, w = 200, h = 36 }

local SettingsMenu = {}
SettingsMenu.__index = SettingsMenu

function SettingsMenu.new(settings_state, scene_manager, on_exit)
    local self = setmetatable({}, SettingsMenu)
    self.is_open          = false
    self.selected         = 1
    self._state           = settings_state or SettingsState.new()
    self._scene_manager   = scene_manager
    self._on_exit         = on_exit
    return self
end

function SettingsMenu:open()
    self.is_open  = true
    self.selected = 1
end

function SettingsMenu:close()
    self.is_open = false
end

function SettingsMenu:update(_dt)
end

function SettingsMenu:_on_exit_to_menu()
    Save.write_settings(self._state:to_save())
    self:close()
    if self._on_exit then
        self._on_exit()
    else
        local StartScene = require("lua/game/scenes/start_scene")
        self._scene_manager:switch(StartScene.new(self._scene_manager, self._state))
    end
end

function SettingsMenu:_on_confirm()
    if self.selected == 3 then
        self:close()
    elseif self.selected == 4 then
        self:_on_exit_to_menu()
    end
end

function SettingsMenu:key_pressed(key)
    if not self.is_open then return false end

    if key == "escape" then
        self:close()
        return true
    end

    if key == "return" or key == "space" then
        self:_on_confirm()
        return true
    end

    if key == "up" or key == "w" then
        self.selected = ((self.selected - 2) % 4) + 1
        return true
    end

    if key == "down" or key == "s" then
        self.selected = (self.selected % 4) + 1
        return true
    end

    if key == "left" or key == "a" then
        if self.selected == 1 then
            self._state:set_sfx_volume(self._state.sfx_volume - 10)
        elseif self.selected == 2 then
            self._state:set_music_volume(self._state.music_volume - 10)
        end
        return true
    end

    if key == "right" or key == "d" then
        if self.selected == 1 then
            self._state:set_sfx_volume(self._state.sfx_volume + 10)
        elseif self.selected == 2 then
            self._state:set_music_volume(self._state.music_volume + 10)
        end
        return true
    end

    return false
end

function SettingsMenu:mouse_pressed(mx, my)
    if not self.is_open then return end

    local e = UI.element_at(self:ui_elements(), mx, my)
    if not e then return end

    if e.id == "settings:sfx_dec" then
        self.selected = 1
        self._state:set_sfx_volume(self._state.sfx_volume - 10)
    elseif e.id == "settings:sfx_inc" then
        self.selected = 1
        self._state:set_sfx_volume(self._state.sfx_volume + 10)
    elseif e.id == "settings:music_dec" then
        self.selected = 2
        self._state:set_music_volume(self._state.music_volume - 10)
    elseif e.id == "settings:music_inc" then
        self.selected = 2
        self._state:set_music_volume(self._state.music_volume + 10)
    elseif e.id == "settings:resume" then
        self:close()
    elseif e.id == "settings:exit" then
        self:_on_exit_to_menu()
    end
end

function SettingsMenu:ui_elements()
    return {
        { id = "settings:sfx_dec",   label = "<",            kind = "button", rect = R_SFX_DEC,   enabled = true },
        { id = "settings:sfx_inc",   label = ">",            kind = "button", rect = R_SFX_INC,   enabled = true },
        { id = "settings:music_dec", label = "<",            kind = "button", rect = R_MUSIC_DEC, enabled = true },
        { id = "settings:music_inc", label = ">",            kind = "button", rect = R_MUSIC_INC, enabled = true },
        { id = "settings:resume",    label = "Resume",       kind = "button", rect = R_RESUME,    enabled = true },
        { id = "settings:exit",      label = "Exit to Menu", kind = "button", rect = R_EXIT,      enabled = true },
    }
end

local function _row_color(selected, row)
    if selected == row then
        return 1, 0.85, 0.2, 1
    end
    return 0.9, 0.9, 0.9, 1
end

function SettingsMenu:draw()
    if not self.is_open then return end

    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Panel background
    love.graphics.setColor(0.15, 0.15, 0.20, 1)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H)
    love.graphics.setColor(0.5, 0.5, 0.6, 1)
    love.graphics.rectangle("line", PANEL_X, PANEL_Y, PANEL_W, PANEL_H)

    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Settings", PANEL_X, PANEL_Y + 18, PANEL_W, "center")

    local font = love.graphics.getFont()
    local fh = font and font.getHeight and font:getHeight() or 16

    -- Row 1: SFX Volume
    local r1, g1, b1, a1 = _row_color(self.selected, 1)
    love.graphics.setColor(r1, g1, b1, a1)
    love.graphics.printf("SFX Volume", PANEL_X + 20, R_SFX_DEC.y + (R_SFX_DEC.h - fh) / 2, 90, "left")
    love.graphics.printf("<", R_SFX_DEC.x, R_SFX_DEC.y + (R_SFX_DEC.h - fh) / 2, R_SFX_DEC.w, "center")
    love.graphics.printf(tostring(self._state.sfx_volume) .. "%", R_SFX_DEC.x + R_SFX_DEC.w + 5, R_SFX_DEC.y + (R_SFX_DEC.h - fh) / 2, 60, "center")
    love.graphics.printf(">", R_SFX_INC.x, R_SFX_INC.y + (R_SFX_INC.h - fh) / 2, R_SFX_INC.w, "center")

    -- Row 2: Music Volume
    local r2, g2, b2, a2 = _row_color(self.selected, 2)
    love.graphics.setColor(r2, g2, b2, a2)
    love.graphics.printf("Music Volume", PANEL_X + 20, R_MUSIC_DEC.y + (R_MUSIC_DEC.h - fh) / 2, 90, "left")
    love.graphics.printf("<", R_MUSIC_DEC.x, R_MUSIC_DEC.y + (R_MUSIC_DEC.h - fh) / 2, R_MUSIC_DEC.w, "center")
    love.graphics.printf(tostring(self._state.music_volume) .. "%", R_MUSIC_DEC.x + R_MUSIC_DEC.w + 5, R_MUSIC_DEC.y + (R_MUSIC_DEC.h - fh) / 2, 60, "center")
    love.graphics.printf(">", R_MUSIC_INC.x, R_MUSIC_INC.y + (R_MUSIC_INC.h - fh) / 2, R_MUSIC_INC.w, "center")

    -- Row 3: Resume
    local r3, g3, b3, a3 = _row_color(self.selected, 3)
    love.graphics.setColor(r3, g3, b3, a3)
    love.graphics.printf("Resume", R_RESUME.x, R_RESUME.y + (R_RESUME.h - fh) / 2, R_RESUME.w, "center")

    -- Row 4: Exit to Menu
    local r4, g4, b4, a4 = _row_color(self.selected, 4)
    love.graphics.setColor(r4, g4, b4, a4)
    love.graphics.printf("Exit to Menu", R_EXIT.x, R_EXIT.y + (R_EXIT.h - fh) / 2, R_EXIT.w, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

return SettingsMenu
