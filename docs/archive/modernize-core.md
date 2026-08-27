## Modernize Core Checklist

- [x] Task A — `core/lua/camera.lua` — Remove `local LOGICAL_W, LOGICAL_H = 1280, 720` from the top; change `Camera.new(x, y)` → `Camera.new(x, y, w, h)`; add `self._w = w or 1280` and `self._h = h or 720` to the constructor; replace `love.graphics.translate(LOGICAL_W / 2, LOGICAL_H / 2)` with `love.graphics.translate(self._w / 2, self._h / 2)` in `attach()`. No other changes.

- [x] Task B — `core/lua/scene.lua` — Two fixes: (1) change `require("lua/core/drawer")` → `require("core/lua/drawer")` and `require("lua/core/camera")` → `require("core/lua/camera")`; (2) change `Scene.new()` → `Scene.new(w, h)` and `Camera.new()` → `Camera.new(0, 0, w, h)`. No other changes.

- [x] Task C — `core/lua/scene_manager.lua` — Rename `self._W` → `self._w` and `self._H` → `self._h` in the constructor, and update the matching `self._W` / `self._H` references in `draw()` to `self._w` / `self._h`. No other changes.

- [x] Task D — `game/scenes/game_scene.lua` — Refactor to extend `Scene` (depends on Task B being done first). Specifically: add `local Scene = require("core/lua/scene")` near the top; remove `local Drawer = require("core/lua/drawer")` and `local Camera = require("core/lua/camera")`; in `GameScene.new()` replace `setmetatable({}, GameScene)` / `self.drawer = Drawer.new()` / `self.camera = Camera.new()` with `local self = Scene.new(1280, 720)` then `setmetatable(self, GameScene)`; delete `GameScene:on_exit()` entirely (Scene:on_exit already clears the drawer); in `GameScene:draw()` replace the `self.camera:attach() / self.drawer:draw() / self.camera:detach()` block with `Scene.draw(self)`, keeping the HUD print lines after it unchanged.
