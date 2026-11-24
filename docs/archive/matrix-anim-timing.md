## Matrix Animation Timing Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — In `do_step()`, set `self._anim_display_matrix = mat` before `_process_footprint`; clear it in `do_reset()`, `start_run()` and `load_puzzle()`. Add `MatrixScene:_display_matrix()` (returns `_anim_display_matrix` while `anim_t < 1`, else `current_matrix`) and use it in `draw_travelling_matrix()` and `ui_matrix()`.
- [x] Task B — `tests/test_matrix_anim_timing.lua` — Unit tests: mid-animation display matrix is pre-op, at rest it is post-op, reset/start clear it, and the puzzle's frame-by-frame display matches the recap's recorded `frame.matrix`.
- [x] Task C — `tests/ui/09_anim_timing.lua` — UI spec: place a pusher on a puzzle with an op via real clicks, Run, and assert via `assert_matrix` that the shown matrix is pre-op while sliding into the op and post-op once at rest.
