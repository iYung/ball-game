## Goal

Bring `core/lua/` up to the same standard as the modernized `/core` in the reference project (wip). Three core files need updating, and `game_scene.lua` should be refactored to extend `Scene` like wip's game scenes do.

## Affected files

- `core/lua/camera.lua` — remove hardcoded `1280, 720`; add `w, h` to constructor
- `core/lua/scene.lua` — add `w, h` to constructor; fix broken require paths (`lua/core/` → `core/lua/`)
- `core/lua/scene_manager.lua` — rename `_W/_H` → `_w/_h` to match wip exactly
- `game/scenes/game_scene.lua` — refactor to extend `Scene` instead of creating its own `Drawer`/`Camera`

## What changes

### 1. core/lua/camera.lua

Remove `local LOGICAL_W, LOGICAL_H = 1280, 720` at the top. Change `Camera.new(x, y)` to `Camera.new(x, y, w, h)`. Store `self._w = w or 1280` and `self._h = h or 720`. Replace `love.graphics.translate(LOGICAL_W / 2, LOGICAL_H / 2)` with `love.graphics.translate(self._w / 2, self._h / 2)`.

### 2. core/lua/scene.lua

Two fixes in one file:

**Broken require paths**: `require("lua/core/drawer")` and `require("lua/core/camera")` don't exist in this project. Change both to `require("core/lua/drawer")` and `require("core/lua/camera")`.

**Dimension threading**: Change `Scene.new()` → `Scene.new(w, h)` and `Camera.new()` → `Camera.new(0, 0, w, h)`. This mirrors wip exactly.

### 3. core/lua/scene_manager.lua

Two-line rename: `self._W` → `self._w` and `self._H` → `self._h` (plus the matching reference in `draw()`). The constructor already accepts `w, h` — this just aligns the field names with wip.

### 4. game/scenes/game_scene.lua

Refactor to extend `Scene` as its base, like wip's game scenes:

- Add `local Scene = require("core/lua/scene")`
- Remove `local Drawer = require("core/lua/drawer")` and `local Camera = require("core/lua/camera")` (Scene provides both)
- Change `GameScene.new()` to call `Scene.new(1280, 720)` and re-set the metatable: `local self = Scene.new(1280, 720); setmetatable(self, GameScene)`
- Remove `self.drawer = Drawer.new()` and `self.camera = Camera.new()` from the constructor (now inherited)
- Remove `GameScene:on_exit()` — `Scene:on_exit()` already clears the drawer
- In `GameScene:draw()`, replace the manual `camera:attach/draw/detach` block with `Scene.draw(self)`, then append the HUD prints after

## What stays the same

- `drawer.lua`, `fonts.lua`, `input.lua`, `shader.lua`, `sprite.lua`, `spriteset.lua`, `timer.lua` — identical to wip, no changes
- `main.lua`, `lua/headless/`, `game/player.lua`, `conf.lua` — untouched
- All require paths in files other than `scene.lua` and `game_scene.lua` — untouched
- The game's visible behavior is unchanged

## Open questions

None — design is approved.
