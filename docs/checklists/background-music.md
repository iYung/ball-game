# Background Music Checklist

## Group A — Foundation (sequential)

- [x] Task A1 — `lua/core/sound.lua` — Replace the stub with the full wip implementation, music-only scope. Port these functions from `/root/wip/lua/core/sound.lua` verbatim (adjusting only where the wip uses SFX/animalese which we omit): `Sound.load(manifest)` (loads only `manifest.music`; skip sfx/animalese keys if present), `Sound.update(dt)`, `Sound.play_music(name)`, `Sound.fade_music(name, target_vol, duration)`, `Sound.stop_music(name)`, `Sound.is_music_playing(name)`, `Sound.set_music_volume(v)` (clamp [0,1], apply to all playing tracks), `Sound.set_sfx_volume(v)` (store only — no SFX sources to update), `Sound.on_focus(focused)`. Keep the existing `Sound.get_sfx_volume()` and `Sound.get_music_volume()` getters that `SettingsState` relies on. Guard every `love.audio` call with `if not love.audio then return end`.

- [x] Task A2 — `lua/headless/stubs.lua` — already had all required stub-source methods; no change needed — Audit the `love.audio.newSource` stub. The expanded Sound module calls `src:setLooping(bool)`, `src:setVolume(n)`, `src:play()`, `src:stop()`, `src:isPlaying()`, `src:clone()` (returns another stub source), `src:getPitch` and `src:setPitch` are NOT needed (SFX only). Make sure the stub source returned by `newSource` has all required methods as no-ops returning sensible defaults (`isPlaying` → `false`, `clone` → another stub source). Do not break any currently-passing test.

## Group B — Assets and wiring (parallel after Group A)

- [x] Task B1 — `assets/music/` — Create the directory and copy the five files from `/root/wip/assets/music/`: `menu.mp3`, `background.mp3`, `background2.mp3`, `background3.mp3`, `background4.mp3`. Use `cp` — no conversion needed.

- [x] Task B2 — `main.lua` — Three additions: (1) `require("lua/core/sound")` near the top (after other requires). (2) In `love.load()`, after `manager:switch(StartScene.new(...))`, call `Sound.load({ music = { menu={path="assets/music/menu.mp3", looping=true, autoplay=true}, bg1={path="assets/music/background.mp3", looping=false}, bg2={path="assets/music/background2.mp3", looping=false}, bg3={path="assets/music/background3.mp3", looping=false}, bg4={path="assets/music/background4.mp3", looping=false} } })`. (3) In `love.update(dt)`, call `Sound.update(dt)` before `manager:update(dt)`. (4) Add `function love.focus(focused) Sound.on_focus(focused) end` at the bottom. Skip the Sound.load call when `_visual_mode` is true (or guard: load only inside the non-visual branch).

- [x] Task B3 — `lua/game/scenes/start_scene.lua` — In `on_enter()`, after existing setup, add: `local Sound = require("lua/core/sound"); if not Sound.is_music_playing("menu") then Sound.play_music("menu") end`. The guard prevents restarting the track when returning from level select.

- [x] Task B4 — `lua/game/scenes/level_select_scene.lua` — In `on_enter()`, after existing setup, same two lines as B3. Covers the edge case where level select is entered without passing through start scene.

- [x] Task B5 — `lua/game/scenes/matrix_scene.lua` — Two changes: (1) In `on_enter()`: `local Sound = require("lua/core/sound"); Sound.fade_music("menu", 0, 2); local _bgs = {"bg1","bg2","bg3","bg4"}; self._bg_track = _bgs[math.random(#_bgs)]; self._prev_bg_track = self._bg_track; Sound.fade_music(self._bg_track, 1, 2)`. (2) In `update(dt)`, before the overlay early-return: check `if self._bg_track and not Sound.is_music_playing(self._bg_track) then` — pick a new random bg track (avoid repeating `self._prev_bg_track` when possible), store it in `self._bg_track` and `self._prev_bg_track`, call `Sound.fade_music(self._bg_track, 1, 1)`.

- [x] Task B6 — `lua/game/scenes/settings_menu.lua` — In `_on_confirm()` (or wherever "Exit to Menu" action fires), before switching to StartScene, add: `local Sound = require("lua/core/sound"); for _, n in ipairs({"bg1","bg2","bg3","bg4"}) do Sound.fade_music(n, 0, 1) end`. Read the file first to find the exact location (`settings:exit` branch).
