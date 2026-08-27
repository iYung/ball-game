## Goal

Identify improvements in `/root/wip` (a full-featured plant shop game) worth back-porting into `/root/love-exemplar` (the minimal engine-exemplar project). The exemplar is not a game port — its purpose is to demonstrate clean Love2D architecture patterns. Candidates should be improvements to the **core engine layer** or **project scaffolding** that make the exemplar more useful as a reference, without importing game-specific gameplay logic.

---

## Affected files

| File | Action | Reason |
|------|--------|--------|
| `core/lua/scene_manager.lua` | Replace | Add fade-transition system |
| `core/lua/fonts.lua` | Add (new file) | Font factory pattern |
| `core/lua/scene.lua` | Already identical | No change needed |
| `main.lua` | Update | Canvas rendering, pixel-art filter, headless mode, window config |
| `conf.lua` | Add (new file) | `love.conf` with resizable window and headless module suppression |
| `lua/headless/stubs.lua` | Add (new dir+file) | Headless test stubs |
| `lua/headless/input.lua` | Add (new file) | `HeadlessInput` for scriptable tests |
| `lua/headless/runner.lua` | Add (new file) | Test runner (`setup`, `tick`, `run`) |
| `tests/` | Add (new dir) | Example test demonstrating the test infrastructure |

Note: `core/lua/` require paths in love-exemplar use `core/lua/…`, while wip uses `lua/core/…`. All ported files must keep or adapt require paths to match love-exemplar's layout (`core/lua/…`, `game/…`).

---

## What changes

### 1. `core/lua/scene_manager.lua` — fade transitions

**wip version** adds a black-screen fade between scene switches (0.3 s fade-out then fade-in). The exemplar's current `SceneManager` does a hard-cut swap with no visual transition.

Key additions:
- `FADE_DURATION = 0.3` constant
- `_prev`, `_fade_state`, `_fade_alpha` fields
- `switch()` triggers fade-out unless it is the first scene load (no-op guard)
- `update(dt)` drives the alpha: `"out"` ramps up, calls `_prev:on_exit()` at peak, then `"in"` ramps back down
- `draw()` renders the old scene during fade-out (so it darkens), then the new scene; overlays a black rectangle with `_fade_alpha` opacity

**What to adapt:** The wip version depends on `require("lua/game/config")` for `config.LOGICAL_W/H`. The exemplar should either hardcode `1280, 720` (matching the camera module) or introduce a minimal config table.

### 2. `core/lua/fonts.lua` — font factory (new file)

**wip** adds `lua/core/fonts.lua`: a tiny factory that binds a font file and hinting mode once, then exposes `obj.new(size)` for callers. This avoids scattering `love.graphics.newFont(path, size, "light")` calls everywhere.

```lua
return {
    from = function(path, hinting)
        hinting = hinting or "light"
        return { new = function(size) return love.graphics.newFont(path, size, hinting) end }
    end
}
```

No game-specific knowledge. Clean utility worth adding to the exemplar's core.

### 3. `main.lua` — canvas rendering + pixel-art filter + window config

The wip `main.lua` adds several improvements over the exemplar's minimal version:

- **Off-screen canvas rendering** — draws the scene into a `LOGICAL_W × LOGICAL_H` canvas, then scales it to the window with letterboxing. This is the standard way to handle resizable windows at a fixed logical resolution in Love2D. Current exemplar draws directly to the backbuffer.
- **`love.graphics.setDefaultFilter("nearest", "nearest")`** — pixel-art default filter applied globally at startup.
- **`love.window.setIcon`** — loads `assets/images/icon.png` as the window icon (can stay as-is or use exemplar's player.png).
- **Font loading** — `love.graphics.setNewFont(path, size, hinting)` sets a default font at startup.

The headless / visual test mode plumbing is also in `main.lua` (see item 5 below).

### 4. `conf.lua` — love.conf (new file)

wip has a `conf.lua` that does two things the exemplar lacks:

- Sets `t.window.resizable = true` so the window can be dragged to any size (canvas rendering + letterboxing makes this seamless).
- When `--headless` is in `arg`, disables the `window`, `graphics`, `audio`, `sound`, `joystick`, `touch`, and `video` Love2D modules so the process starts faster and truly windowless for CI.

The exemplar currently has no `conf.lua` at all.

### 5. Headless test infrastructure — `lua/headless/` (new directory)

wip has a complete headless testing framework with no game-specific dependencies. All three files are directly portable:

**`lua/headless/stubs.lua`**
Installs no-op replacements for `love.graphics`, `love.keyboard`, `love.window`, `love.filesystem`, and `love.audio` before any game module loads. Uses a metatable catch-all on the graphics stub so any unknown `love.graphics.new*` returns a stub image object with `getWidth`/`getHeight`/`getDimensions`/`setFilter`.

**`lua/headless/input.lua`** (`HeadlessInput`)
A scriptable drop-in for `core/lua/input.lua`. Tests drive it with `press(action)` (single-frame fire), `hold(action)` (held until `release`), and `release(action)`. `update()` rebuilds `_down` and `_pressed` each frame without touching `love.keyboard`.

**`lua/headless/runner.lua`**
- `runner.setup(scene_factory)` — creates a `GameState`, `HeadlessInput`, and `SceneManager`; wires them; switches to the scene
- `runner.tick(input, sm, n, dt)` — advances `n` frames (default 1) at `dt` seconds each (default 1/60)
- `runner.fast_forward_until(ctx, fn, elapsed, cap)` — loops `tick(dt=1.0)` until `fn()` returns true
- `runner.run(test_file)` — discovers and runs all `tests/*.lua` files; prints `PASS / FAIL` per file; quits with exit code 0/1
- Visual mode (`_visual = true`) yields the coroutine after each tick so `love.draw` renders between steps

Note: `runner.lua` imports `GameState` and `StartScene` — these are game-specific. For the exemplar, a simpler runner that only imports `GameScene` (the exemplar's single scene) would be preferable, or the imports can be made optional via a `scene_factory` argument.

### 6. `tests/` — example test (new directory)

wip has 19 test files. The exemplar needs at least one to demonstrate the infrastructure. A minimal `tests/test_basics.lua` showing:
- How to `require` the runner
- How to call `runner.setup()` with a custom scene factory
- How to `runner.tick()` and assert on state

No game logic needs porting; the test should exercise exemplar's own `GameScene` (player movement, camera follow, coin blinking).

---

## What stays the same

- **All 9 core engine files** (`camera`, `drawer`, `input`, `scene`, `scene_manager` pre-fade, `shader`, `sprite`, `spriteset`, `timer`) are **byte-for-byte identical** between the two repos. No changes needed to any of them except `scene_manager` (item 1 above).
- **`game/player.lua`** — the exemplar's player is intentionally minimal (WASD + single sprite). wip's player is deeply game-specific (4-sprite SpriteSet, ColorReplace shader, held-item system, speed tiers, store bounds clamping). Not worth porting.
- **`game/scenes/game_scene.lua`** — the exemplar's scene demonstrates Camera + Drawer + Timer + Sprite patterns clearly. wip's `store_scene.lua` is a 540-line game-specific scene. Not worth porting.
- **All game-specific modules** — `assets.lua`, `sound.lua`, `save.lua`, `game_state.lua`, `settings_state.lua`, `store.lua`, `slot.lua`, `customer.lua`, `water_drone.lua`, all item subclasses, all shaders, all data tables, all scenes (`start_scene`, `buy_scene`, `settings_menu`) — none of these belong in the exemplar.
- **`core/lua/README.md`** — already documents the core classes accurately. No update needed.
- **Require path convention** — love-exemplar uses `core/lua/…` and `game/…`. wip uses `lua/core/…` and `lua/game/…`. The exemplar's paths are fine; ported files must adapt.
- **Asset directory** — exemplar keeps `assets/player.png`. No asset migration needed.

---

## Open questions

1. **Config table for SceneManager** — The wip `scene_manager.lua` imports `lua/game/config` for `LOGICAL_W` / `LOGICAL_H`. For the exemplar, should the ported version hardcode `1280, 720` (matching camera.lua), accept them as constructor args, or introduce a `core/lua/config.lua` with just those two constants?

2. **Fonts file** — Should `core/lua/fonts.lua` be ported as a core utility (no font path baked in) and `game/fonts.lua` (thin wrapper binding the font file) be added alongside, mirroring wip's pattern? Or is a single `core/lua/fonts.lua` with no path sufficient?

3. **runner.lua game-state dependency** — `runner.lua` as-is imports `GameState` and `StartScene`. For the exemplar, the simplest fix is to remove those imports and require callers to always pass a `scene_factory`. Is that acceptable, or should the exemplar include a stub `game_state.lua`?

4. **Test scope** — How many example tests should be added? One minimal `test_basics.lua` (player moves, camera follows) is likely enough to demonstrate the infrastructure without duplicating wip's full test suite.

5. **Window icon** — `conf.lua` and `main.lua` reference `assets/images/icon.png`. Should the exemplar add a placeholder icon PNG, reuse `assets/player.png`, or omit the `setIcon` call?
