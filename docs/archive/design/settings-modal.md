# Settings Modal

## Goal

Add an in-game pause/settings overlay accessible from `MatrixScene` and `LevelSelectScene` via
ESC. The overlay exposes SFX and music volume controls, backed by a new Sound module and
persisted to `settings.dat` on close.

## Affected files

| File | Change |
|------|--------|
| `lua/core/sound.lua` | **New** — SFX / music volume API |
| `lua/core/save.lua` | **New** — settings persistence (`write_settings` / `read_settings`) |
| `lua/game/settings_state.lua` | **New** — in-memory settings data + volume callbacks |
| `lua/game/scenes/settings_menu.lua` | **New** — overlay drawn with primitives |
| `main.lua` | Load settings at startup; pass to scenes; route `keypressed` to overlay |
| `lua/game/scenes/matrix_scene.lua` | ESC opens settings overlay instead of switching scenes |
| `lua/game/scenes/level_select_scene.lua` | ESC opens settings overlay instead of switching scenes |
| `tests/ui/test_settings_menu.lua` | **New** — UI spec covering open/close, volume adjust |

## What changes

### Sound module (`lua/core/sound.lua`)

Thin wrapper over `love.audio`. Tracks a master SFX volume and a music volume.  
Two public functions are all that's needed here:

```
Sound.set_sfx_volume(v)    -- 0–1
Sound.set_music_volume(v)  -- 0–1
```

No audio files are loaded by this feature; the module just stores the levels and applies them
when `love.audio` calls are made in future.

### Save module (`lua/core/save.lua`)

Serialiser already exists in the wip reference implementation; port it verbatim:

```
Save.settings_exist()      → bool
Save.write_settings(data)  → writes settings.dat
Save.read_settings()       → table | nil
```

`save.dat` (game progress) is out of scope for this feature.

### SettingsState (`lua/game/settings_state.lua`)

Holds `sfx_volume` (0–100) and `music_volume` (0–100). Mutation methods call through to Sound:

```
SettingsState.new()
SettingsState.from_save(data)
state:set_sfx_volume(v)
state:set_music_volume(v)
state:to_save()
```

No fullscreen or keybind support — out of scope for this feature.

### SettingsMenu overlay (`lua/game/scenes/settings_menu.lua`)

Not a scene — an overlay object that scenes hold and delegate to.  
Drawn with primitives (no sprite assets required).

```
SettingsMenu.new(settings_state, on_close)
menu:open()
menu:close()
menu:update(dt)
menu:key_pressed(key)
menu:draw()
```

Layout (1280×720):
- Semi-transparent dark rectangle covers the screen
- Title: "Settings"
- Row 1: "SFX Volume" label + current value + left/right arrows
- Row 2: "Music Volume" label + current value + left/right arrows
- Row 3: "Resume" button (closes overlay)
- Row 4: "Exit to Menu" button (switches to StartScene)

Navigation: arrow keys or WASD to move between rows; left/right to adjust volume; Enter/Space
to confirm; ESC closes.

The menu writes settings to disk via `Save.write_settings` whenever a volume changes.

### main.lua

`love.load()` reads `settings.dat` and constructs a singleton `SettingsState`. It is passed into
`StartScene.new()`, which forwards it to `LevelSelectScene`, which forwards it to `MatrixScene`.

A `love.keypressed` call on the active scene's overlay (if open) is handled before the scene.

### Scene changes

`MatrixScene` and `LevelSelectScene` each gain:
- A `SettingsMenu` member constructed in their constructor with their `settings_state`.
- ESC handling: if overlay is closed, open it; if open, close it (Resume).
- Delegation of `update`, `key_pressed`, and `draw` to the overlay when `is_open`.

The old ESC-to-navigate behaviour is replaced by ESC-to-pause. Navigation back is handled by
the overlay's "Exit to Menu" button.

## What stays the same

- `Input` class — no changes
- Scene manager — no changes  
- Puzzle logic — no changes
- `StartScene` — no changes (settings not accessible from start menu)
- `Progress` / save game — no changes
- All existing tests

## Open questions

None — scope confirmed by user before design was written.
