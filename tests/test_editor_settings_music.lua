-- Going through the editor keeps the player's volume settings, and the menu music
-- comes back after leaving a puzzle (editor Test or level select). Driven through real input from the title screen; a unit
-- test because it needs a loaded settings state, the settings file and audio sources.

local UIRunner      = require("lua/headless/ui_runner")
local StartScene    = require("lua/game/scenes/start_scene")
local SettingsState = require("lua/game/settings_state")
local Save          = require("lua/core/save")
local Sound         = require("lua/core/sound")

local function run(steps, make_scene)
    local ok, err = UIRunner.run_spec({ given = { solved = {} }, steps = steps },
        { make_scene = make_scene })
    assert(ok, tostring(err))
end

local OPEN_TEST = { { click_button = "Editor" }, { click_button = { id = "editor:test" } } }

local function steps_after_open(...)
    local steps = {}
    for _, s in ipairs(OPEN_TEST) do steps[#steps + 1] = s end
    for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
    return steps
end

local EXIT = { click_button = { id = "settings:exit" } }

-- ── Volume settings ───────────────────────────────────────────────────────

do
    local real_write, written = Save.write_settings, {}
    Save.write_settings = function(data) written[#written + 1] = data end
    local function with_saved_volumes(sm)
        return StartScene.new(sm, SettingsState.from_save({ sfx_volume = 40, music_volume = 30 }))
    end
    local ok, err = pcall(function()
        run(steps_after_open({ press = "escape" }, { assert_text = "40%" }, { assert_text = "30%" },
            EXIT, { assert_text = "PUZZLE EDITOR" }), with_saved_volumes)
        assert(#written == 1, "Exit to Menu writes settings once")
        assert(written[1].sfx_volume == 40 and written[1].music_volume == 30,
            "Exit to Menu in Test keeps the saved volumes")

        -- Editor -> title -> level select still has them, by Back button and by Esc.
        for _, leave in ipairs({ { click_button = { id = "editor:back" } }, { press = "escape" } }) do
            run({ { click_button = "Editor" }, leave, { click_button = "Play" },
                { press = "escape" }, { assert_text = "40%" }, { assert_text = "30%" } },
                with_saved_volumes)
        end
    end)
    Save.write_settings = real_write
    Sound.set_sfx_volume(1)
    Sound.set_music_volume(1)
    assert(ok, tostring(err))
    print("PASS: volume settings survive the editor")
end

-- ── Menu music ────────────────────────────────────────────────────────────

do
    local real_new_source = love.audio.newSource
    love.audio.newSource = function()
        local playing = false
        return {
            setLooping = function() end,
            setVolume  = function() end,
            play       = function() playing = true end,
            stop       = function() playing = false end,
            isPlaying  = function() return playing end,
        }
    end
    -- Any existing path will do: the stub source never reads it.
    Sound.load({ music = { menu = { path = "main.lua", autoplay = true } } })

    local function tick(frames)
        return { wait = frames }
    end
    -- main.lua drives Sound.update; the UI runner does not, so do it from the scene manager.
    local function with_audio(sm)
        local update = sm.update
        sm.update = function(self, dt) Sound.update(dt); update(self, dt) end
        return StartScene.new(sm)
    end
    local function check(label, steps)
        run(steps, with_audio)
        assert(Sound.is_music_playing("menu"), label .. ": menu music plays afterwards")
        Sound.stop_music("menu")
    end

    local ok, err = pcall(function()
        -- Long enough for the 2s fade-out to stop the track.
        check("Menu after the fade-out", steps_after_open(tick(180),
            { click_button = { id = "cmd:menu" } }, tick(180)))
        -- Leaving while the track is still fading out must not let it stop afterwards.
        check("Menu during the fade-out", steps_after_open(tick(10),
            { click_button = { id = "cmd:menu" } }, tick(180)))
        check("Exit to Menu", steps_after_open(tick(180), { press = "escape" }, EXIT, tick(180)))

        -- Level select has the same fade to cancel when a puzzle is left quickly.
        local function from_level_select(...)
            local steps = { { click_button = "Play" }, { click_button = { id = "puzzle:1" } }, tick(10) }
            for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
            return steps
        end
        check("level select Menu during the fade-out",
            from_level_select({ click_button = { id = "cmd:menu" } }, tick(180)))
        check("level select Exit to Menu during the fade-out",
            from_level_select({ press = "escape" }, EXIT, tick(180)))
    end)
    love.audio.newSource = real_new_source
    assert(ok, tostring(err))
    print("PASS: menu music returns after leaving a puzzle")
end

print("ALL EDITOR SETTINGS AND MUSIC TESTS PASSED")
