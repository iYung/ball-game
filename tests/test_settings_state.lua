local SettingsState = require("lua/game/settings_state")

-- from_save with nil/non-table: returns defaults
do
    local s = SettingsState.from_save(nil)
    assert(s.sfx_volume == 100,   "from_save(nil): sfx defaults to 100")
    assert(s.music_volume == 100, "from_save(nil): music defaults to 100")
    print("PASS: from_save(nil) returns defaults")
end

-- from_save with valid table: sets volumes from data (lines 33-39)
do
    local s = SettingsState.from_save({ sfx_volume = 50, music_volume = 70 })
    assert(s.sfx_volume == 50,   "from_save valid: sfx_volume = 50")
    assert(s.music_volume == 70, "from_save valid: music_volume = 70")
    print("PASS: from_save valid table sets volumes (lines 33-39)")
end

-- from_save with partial data: only present keys applied
do
    local s = SettingsState.from_save({ sfx_volume = 30 })
    assert(s.sfx_volume == 30,    "from_save partial: sfx_volume = 30")
    assert(s.music_volume == 100, "from_save partial: music_volume stays 100")
    print("PASS: from_save partial data applies only present keys")
end

print("ALL SETTINGS STATE TESTS PASSED")
