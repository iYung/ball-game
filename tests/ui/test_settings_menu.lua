-- Stubs for modules not needed in this spec
package.loaded["lua/core/sound"] = {
    set_sfx_volume   = function() end,
    set_music_volume = function() end,
    get_sfx_volume   = function() return 1 end,
    get_music_volume = function() return 1 end,
    is_music_playing = function() return false end,
    play_music       = function() end,
    fade_music       = function() end,
    stop_music       = function() end,
}
package.loaded["lua/core/save"] = {
    write_settings = function() end,
    read_settings  = function() return nil end,
    settings_exist = function() return false end,
}

local SettingsState = require("lua/game/settings_state")
local SettingsMenu  = require("lua/game/scenes/settings_menu")
local UI            = require("lua/core/ui")

-- Wrapper scene that hosts a SettingsMenu overlay.
-- When closed: exposes a "Settings" button that opens the overlay.
-- When open:   exposes the overlay's ui_elements().
local W_BTN = { x = 540, y = 100, w = 200, h = 36 }

local WrapperScene = {}
WrapperScene.__index = WrapperScene

function WrapperScene.new(sm)
    local self   = setmetatable({}, WrapperScene)
    self._state  = SettingsState.new()
    self._menu   = SettingsMenu.new(self._state, sm)
    return self
end

function WrapperScene:on_enter() end
function WrapperScene:on_exit()  end

function WrapperScene:ui_elements()
    if self._menu.is_open then
        return self._menu:ui_elements()
    end
    return { { id = "wrap:open", label = "Settings", kind = "button", rect = W_BTN, enabled = true } }
end

function WrapperScene:update(dt)
    self._menu:update(dt)
end

function WrapperScene:key_pressed(key)
    if self._menu.is_open then
        return self._menu:key_pressed(key)
    end
end

function WrapperScene:mouse_pressed(mx, my, btn)
    if self._menu.is_open then
        self._menu:mouse_pressed(mx, my)
    elseif btn == 1 and UI.hit(W_BTN, mx, my) then
        self._menu:open()
    end
end

function WrapperScene:draw()
    self._menu:draw()
end

local function make_scene(sm)
    return WrapperScene.new(sm)
end

return {
    {
        name       = "overlay starts closed",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { assert_button = { id = "wrap:open" } },
            { assert_button = { id = "settings:resume", visible = false } },
        },
    },
    {
        name       = "open shows overlay elements",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { assert_button = { id = "settings:resume" } },
            { assert_button = { id = "settings:exit" } },
            { assert_button = { id = "settings:sfx_dec" } },
            { assert_button = { id = "settings:sfx_inc" } },
        },
    },
    {
        name       = "ESC closes overlay",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { assert_button = { id = "settings:resume" } },
            { press = "escape" },
            { assert_button = { id = "settings:resume", visible = false } },
            { assert_button = { id = "wrap:open" } },
        },
    },
    {
        name       = "down navigates to music row; left decrements music volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { press = "down" },              -- row 1 → row 2 (Music)
            { press = "left" },              -- music_volume: 100 → 90
            { assert_text = "90%" },
        },
    },
    {
        name       = "left on SFX row decrements sfx volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },   -- row 1 = SFX (default)
            { press = "left" },              -- sfx_volume: 100 → 90
            { assert_text = "90%" },
        },
    },
    {
        name       = "right on SFX row increments sfx volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { press = "left" },              -- 100 → 90
            { press = "left" },              -- 90 → 80
            { press = "right" },             -- 80 → 90
            { assert_text = "90%" },
        },
    },
    {
        name       = "left/right on music row adjusts music volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { press = "s" },                 -- navigate down to music row
            { press = "left" },              -- music: 100 → 90
            { press = "left" },              -- music: 90 → 80
            { assert_text = "80%" },
        },
    },
    {
        name       = "Enter on Resume closes overlay",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { press = "down" },
            { press = "down" },              -- row 1 → 2 → 3 (Resume)
            { press = "return" },
            { assert_button = { id = "settings:resume", visible = false } },
            { assert_button = { id = "wrap:open" } },
        },
    },
    {
        name       = "Enter on Exit to Menu switches to StartScene",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { press = "down" },
            { press = "down" },
            { press = "down" },              -- row 1 → 2 → 3 → 4 (Exit to Menu)
            { press = "return" },
            { assert_text = "MATRIX PUSH" },
        },
    },
    {
        name       = "clicking Resume ui_element closes overlay",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { click_button = "Resume" },
            { assert_button = { id = "settings:resume", visible = false } },
            { assert_button = { id = "wrap:open" } },
        },
    },
    {
        name       = "clicking SFX dec arrow decrements sfx volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { click_button = { id = "settings:sfx_dec" } },
            { assert_text = "90%" },
        },
    },
    {
        name       = "clicking SFX inc arrow increments sfx volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { click_button = { id = "settings:sfx_dec" } },   -- 100 -> 90
            { click_button = { id = "settings:sfx_inc" } },   -- 90 -> 100
            { assert_text = "100%" },
        },
    },
    {
        name       = "clicking music dec arrow decrements music volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { click_button = { id = "settings:music_dec" } },
            { assert_text = "90%" },
        },
    },
    {
        name       = "clicking music inc arrow increments music volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { click_button = { id = "settings:music_dec" } },   -- 100 -> 90
            { click_button = { id = "settings:music_inc" } },   -- 90 -> 100
            { assert_text = "100%" },
        },
    },
    {
        name       = "clicking Exit to Menu button switches to StartScene",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { click_button = { id = "settings:exit" } },
            { assert_text = "MATRIX PUSH" },
        },
    },
    {
        name       = "up key wraps from row 1 to row 4 (Exit to Menu)",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },   -- opens at row 1 (SFX)
            { press = "up" },                -- row 1 -> row 4 (Exit to Menu)
            { press = "return" },            -- Enter on Exit -> start screen
            { assert_text = "MATRIX PUSH" },
        },
    },
    {
        -- Covers settings_menu.lua lines 105-106: right key on music row (row 2)
        name       = "right key on music row increments music volume",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { press = "s" },                 -- navigate down to music row (row 2)
            { press = "left" },              -- music: 100 → 90
            { press = "right" },             -- music: 90 → 100
            { assert_text = "100%" },
        },
    },
    {
        -- Covers settings_menu.lua line 111: return false for unrecognized key
        name       = "unrecognized key while settings open is a no-op",
        given      = { solved = {} },
        make_scene = make_scene,
        steps = {
            { click_button = "Settings" },
            { assert_button = { id = "settings:resume" } },
            { press = "f" },                      -- unrecognized key → return false
            { assert_button = { id = "settings:resume" } },  -- still open
        },
    },
    {
        -- Covers settings_menu.lua line 55: self._on_exit() when on_exit callback provided
        name       = "on_exit callback fires instead of scene switch",
        given      = { solved = {} },
        make_scene = function(sm)
            local scene  = WrapperScene.new(sm)
            scene._menu  = SettingsMenu.new(scene._state, sm, function() end)
            return scene
        end,
        steps = {
            { click_button = "Settings" },
            { click_button = { id = "settings:exit" } },
            { assert_button = { id = "wrap:open" } },  -- overlay closed, no scene switch
        },
    },
}
