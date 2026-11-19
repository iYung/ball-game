# World Locking Checklist

- [x] Task A — `game/progress.lua` (new file) — Create the progress singleton. Implement `mark_solved(n)`, `is_solved(n)`, `is_world_unlocked(w)` (world 1 always unlocked; world W unlocked if all puzzles in worlds 1..W-1 are solved via `PuzzleLoader`), `unlock_all()`, and `reset()`. Persist to `love.filesystem` as a serialised Lua table (`return {1,3,5,...}`); use `pcall` on load so missing/corrupt file starts fresh; stub-safe (no crash if `love.filesystem.read/write` are no-ops).

- [x] Task B — `lua/headless/stubs.lua` — Extend the existing `love.filesystem` stub table with `read = function() return nil end` and `write = function() end` so `progress.lua` runs in headless/test mode without errors.

- [x] Task C — `game/scenes/solution_recap_scene.lua` — At the top of `on_enter`, require `game/progress` and call `Progress.mark_solved(self._stats.puzzle_index)`.

- [x] Task D — `game/scenes/level_select_scene.lua` — (1) In `draw`, render locked world tabs dimly (colour `0.30, 0.32, 0.42`) and replace the world name with `"[LOCKED]"` text. (2) In `_cycle_world(delta)`, after computing the candidate world index, keep advancing in the same direction until `Progress.is_world_unlocked(candidate)` is true (wrap-safe; World 1 is always unlocked so the loop always terminates).

- [x] Task E — `game/scenes/start_scene.lua` — (1) Add `self._font_debug = love.graphics.newFont(14)` in `on_enter`. (2) In `draw`, below the existing prompt, render a small muted `"(D) Unlock All"` label. (3) In `key_pressed`, handle `"d"` by calling `Progress.unlock_all()` then `self:_advance()`. (4) In `mouse_pressed`, hit-test the "Unlock All" label rect and do the same.
