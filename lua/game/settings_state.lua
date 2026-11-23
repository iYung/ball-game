local Sound = require("lua/core/sound")

local SettingsState = {}
SettingsState.__index = SettingsState

function SettingsState.new()
    local self = setmetatable({}, SettingsState)
    self.sfx_volume   = 100
    self.music_volume = 100
    return self
end

function SettingsState:set_sfx_volume(v)
    self.sfx_volume = math.max(0, math.min(100, v))
    Sound.set_sfx_volume(self.sfx_volume / 100)
end

function SettingsState:set_music_volume(v)
    self.music_volume = math.max(0, math.min(100, v))
    Sound.set_music_volume(self.music_volume / 100)
end

function SettingsState:to_save()
    return {
        sfx_volume   = self.sfx_volume,
        music_volume = self.music_volume,
    }
end

function SettingsState.from_save(data)
    local self = SettingsState.new()
    if type(data) ~= "table" then return self end
    if type(data.sfx_volume) == "number" then
        self:set_sfx_volume(data.sfx_volume)
    end
    if type(data.music_volume) == "number" then
        self:set_music_volume(data.music_volume)
    end
    return self
end

return SettingsState
