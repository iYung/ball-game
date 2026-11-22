# Background Music

## Goal

Play background music appropriate to the current scene, using the wip's Sound module pattern
and its audio assets. Menus play a looping "menu" track; the puzzle scene fades to a rotating
set of non-looping background tracks that chain automatically when each ends.

## Affected files

| File | Change |
|------|--------|
| `lua/core/sound.lua` | Expand from stub to full wip implementation |
| `assets/music/` | **New dir** — copy 5 tracks from wip |
| `main.lua` | `Sound.load(manifest)` on startup; `Sound.update(dt)` each frame; `love.focus` hook |
| `lua/game/scenes/start_scene.lua` | `Sound.play_music("menu")` on enter (if not already playing) |
| `lua/game/scenes/level_select_scene.lua` | Same — menu track continues from start scene |
| `lua/game/scenes/matrix_scene.lua` | Fade out "menu", fade in random bg track; advance track when done |
| `lua/game/scenes/settings_menu.lua` | Fade out all bg tracks when "Exit to Menu" is confirmed |
| `lua/headless/stubs.lua` | Ensure `love.audio.newSource` stub returns a stub source with `isPlaying`, `isConnected`, clone, etc. |

## What changes

### Sound module (`lua/core/sound.lua`)

Port the full wip implementation verbatim, omitting SFX and animalese (music-only scope):

- `Sound.load(manifest)` — loads music tracks from manifest; `manifest.music` is a dict of
  `name → {path, looping, autoplay}`. Checks `love.filesystem.getInfo` before loading so
  missing files are silently skipped (safe if running without assets).
- `Sound.update(dt)` — advances fade timers; stops a track when it fades to 0 if
  `stop_on_done = true`.
- `Sound.play_music(name)` — play immediately at full music volume.
- `Sound.fade_music(name, target_vol, duration)` — fade to target over `duration` seconds;
  `target_vol = 0` with `stop_on_done = true` stops the source when done.
- `Sound.stop_music(name)` — stop immediately, reset fade state.
- `Sound.is_music_playing(name)` — returns bool.
- `Sound.set_music_volume(v)` — clamps [0,1], updates all currently-playing tracks.
- `Sound.set_sfx_volume(v)` — kept for SettingsState compatibility (no-op for music-only scope).
- `Sound.on_focus(focused)` — resumes tracks with `playing_intent = true` on window refocus.

SFX functions (`Sound.play`, `Sound.play_animalese`, `Sound.play_random_music`) are **not**
included; they can be added in a future SFX feature.

### Audio assets

Copy from `/root/wip/assets/music/` into `assets/music/`:

```
assets/music/menu.mp3        — looping menu track (autoplay on load)
assets/music/background.mp3  — puzzle bg track 1 (non-looping)
assets/music/background2.mp3 — puzzle bg track 2 (non-looping)
assets/music/background3.mp3 — puzzle bg track 3 (non-looping)
assets/music/background4.mp3 — puzzle bg track 4 (non-looping)
```

### main.lua

In `love.load()`, after `manager:switch(StartScene.new(...))`:

```lua
Sound.load({
    music = {
        menu = { path = "assets/music/menu.mp3",        looping = true,  autoplay = true },
        bg1  = { path = "assets/music/background.mp3",  looping = false },
        bg2  = { path = "assets/music/background2.mp3", looping = false },
        bg3  = { path = "assets/music/background3.mp3", looping = false },
        bg4  = { path = "assets/music/background4.mp3", looping = false },
    },
})
```

In `love.update(dt)`: call `Sound.update(dt)` before `manager:update(dt)`.

Add `love.focus = function(focused) Sound.on_focus(focused) end`.

### StartScene (`on_enter`)

```lua
if not Sound.is_music_playing("menu") then
    Sound.play_music("menu")
end
```

### LevelSelectScene (`on_enter`)

Same check — menu track will already be playing if coming from StartScene; this is a no-op
in that case but covers direct entry in tests.

### MatrixScene (`on_enter` and `update`)

On enter:
```lua
Sound.fade_music("menu", 0, 2)   -- fade out menu over 2 s
-- pick a random bg track and fade it in
local bg_names = {"bg1","bg2","bg3","bg4"}
self._bg_track = bg_names[math.random(#bg_names)]
Sound.fade_music(self._bg_track, 1, 2)
```

In `update(dt)` (before overlay early-return):
```lua
-- When the current bg track ends, pick and start the next one
if self._bg_track and not Sound.is_music_playing(self._bg_track) then
    local bg_names = {"bg1","bg2","bg3","bg4"}
    repeat
        self._bg_track = bg_names[math.random(#bg_names)]
    until #bg_names == 1 or self._bg_track ~= self._prev_bg_track
    self._prev_bg_track = self._bg_track
    Sound.fade_music(self._bg_track, 1, 1)
end
```

### SettingsMenu (`_on_exit_to_menu`)

Fade out all bg tracks before switching to StartScene:

```lua
for _, name in ipairs({"bg1","bg2","bg3","bg4"}) do
    Sound.fade_music(name, 0, 1)
end
```

(The menu track restores itself via `StartScene.on_enter`.)

### Headless stubs

The existing `love.audio.newSource` stub returns an object; it needs `isPlaying()`,
`play()`, `stop()`, `setVolume()`, `setLooping()`, `clone()` returning a similar stub.
Verify these are present and add any missing ones.

## What stays the same

- CutsceneScene — menu track continues passively (no change needed)
- SolutionRecapScene — bg track continues passively (no change needed)
- All SFX code paths — not wired up yet
- Test infrastructure — conf.lua disables audio under `--headless`; stubs handle the rest
- Settings volume controls — already wired to `Sound.set_music_volume`

## Open questions

None — scope confirmed before design was written.
