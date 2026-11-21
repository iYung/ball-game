local Sound = {}

local _sfx_volume   = 1.0
local _music_volume = 1.0
local _music_tracks = {}

function Sound.load(manifest)
    if not love.audio then return end
    if manifest.music then
        for name, track in pairs(manifest.music) do
            if love.filesystem.getInfo(track.path) then
                local autoplay = track.autoplay or false
                local src = love.audio.newSource(track.path, "stream")
                src:setLooping(track.looping ~= false)
                src:setVolume(autoplay and _music_volume or 0)
                _music_tracks[name] = {
                    src            = src,
                    fade_vol       = 1,
                    fade_target    = 1,
                    fade_rate      = 0,
                    stop_on_done   = false,
                    playing_intent = autoplay,
                }
                if autoplay then
                    src:play()
                end
            end
        end
    end
end

function Sound.update(dt)
    for _, entry in pairs(_music_tracks) do
        if entry.fade_rate ~= 0 then
            entry.fade_vol = entry.fade_vol + entry.fade_rate * dt
            if entry.fade_vol < 0 then entry.fade_vol = 0 end
            if entry.fade_vol > 1 then entry.fade_vol = 1 end
            entry.src:setVolume(entry.fade_vol * _music_volume)
            if (entry.fade_rate > 0 and entry.fade_vol >= entry.fade_target) or
               (entry.fade_rate < 0 and entry.fade_vol <= entry.fade_target) then
                entry.fade_vol = entry.fade_target
                entry.src:setVolume(entry.fade_vol * _music_volume)
                entry.fade_rate = 0
                if entry.stop_on_done then
                    entry.src:stop()
                    entry.playing_intent = false
                    entry.stop_on_done = false
                end
            end
        end
    end
end

function Sound.play_music(name)
    if not love.audio then return end
    local entry = _music_tracks[name]
    if entry then
        entry.fade_vol     = 1
        entry.fade_target  = 1
        entry.fade_rate    = 0
        entry.stop_on_done = false
        entry.src:setVolume(_music_volume)
        entry.src:play()
        entry.playing_intent = true
    end
end

function Sound.fade_music(name, target_vol, duration)
    if not love.audio then return end
    local entry = _music_tracks[name]
    if entry then
        if target_vol > 0 and not entry.src:isPlaying() then
            entry.fade_vol = 0
            entry.src:setVolume(0)
            entry.src:play()
            entry.playing_intent = true
        end
        entry.fade_target  = target_vol
        entry.fade_rate    = (target_vol - entry.fade_vol) / duration
        entry.stop_on_done = (target_vol == 0)
    end
end

function Sound.stop_music(name)
    if not love.audio then return end
    local entry = _music_tracks[name]
    if entry then
        entry.src:stop()
        entry.playing_intent = false
        entry.fade_vol     = 1
        entry.fade_target  = 1
        entry.fade_rate    = 0
        entry.stop_on_done = false
    end
end

function Sound.is_music_playing(name)
    local entry = _music_tracks[name]
    if entry == nil then return false end
    return entry.src:isPlaying()
end

function Sound.set_sfx_volume(v)
    _sfx_volume = math.max(0, math.min(1, v))
end

function Sound.set_music_volume(v)
    _music_volume = math.max(0, math.min(1, v))
    for _, entry in pairs(_music_tracks) do
        if entry.src:isPlaying() then
            entry.src:setVolume(entry.fade_vol * _music_volume)
        end
    end
end

function Sound.get_sfx_volume()   return _sfx_volume   end
function Sound.get_music_volume() return _music_volume end

function Sound.on_focus(focused)
    if not love.audio then return end
    if focused then
        for _, entry in pairs(_music_tracks) do
            if entry.playing_intent == true and entry.src:isPlaying() == false then
                entry.src:setVolume(entry.fade_vol * _music_volume)
                entry.src:play()
            end
        end
    end
end

return Sound
