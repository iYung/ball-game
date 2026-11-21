local Sound = {}

local _sfx_volume   = 1
local _music_volume = 1

function Sound.set_sfx_volume(v)
    _sfx_volume = math.max(0, math.min(1, v))
end

function Sound.set_music_volume(v)
    _music_volume = math.max(0, math.min(1, v))
end

function Sound.get_sfx_volume()   return _sfx_volume   end
function Sound.get_music_volume() return _music_volume end

return Sound
