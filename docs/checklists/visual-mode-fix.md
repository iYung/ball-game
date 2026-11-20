## Visual mode fix Checklist

- [ ] Task A — `main.lua` — When `_visual_mode` is true and `_visual_test` is a UI spec path (`tests/ui/` prefix), print an error message and call `love.event.quit(1)` immediately inside the new `love.load()` branch so we don't silently hang.
- [ ] Task B — `main.lua` — When `_visual_mode` is true and `_visual_test` is a unit test path (or nil): require `lua/headless/runner`, set `runner._visual = true`, wrap `dofile(_visual_test)` in a coroutine stored as `_visual_co`, and set `manager` to nil so the normal update/draw path is skipped.
- [ ] Task C — `main.lua` — In `love.update(dt)`, before the normal `manager:update(dt)` call, add a branch: if `_visual_co` is set and suspended, resume it; if it returns finished or errored, print PASS/FAIL and quit.
- [ ] Task D — `main.lua` — In `love.draw()`, add a branch: if `runner` is set and `runner._active_sm` is non-nil, draw from `runner._active_sm` instead of `manager` (same canvas/scale logic).
