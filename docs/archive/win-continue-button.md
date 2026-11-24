# Win → Continue Button Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — Add `{ id="continue", label="Cont.", color_fill={0.12,0.28,0.12}, color_border={0.30,0.75,0.30} }` to `CMD_BUTTONS`; in `_cmd_enabled` return true for "continue" only when `self.status == "win"`; in `_cmd_activate` handle "continue" by building stats/board tables and calling `self._scene_manager:switch(SolutionRecapScene.new(...))` (move the logic that was in `update()`); in `key_pressed` add `elseif key == "return" and self.status == "win"` branch that calls `self:_cmd_activate("continue")`.

- [x] Task B — `lua/game/scenes/matrix_scene.lua` — Remove the entire `_win_timer` auto-transition block from `update()` (the `if self.status == "win"` block that increments `_win_timer` and switches scenes); remove `self._win_timer = nil` from `MatrixScene.new`, `load_puzzle`, and `do_reset`.

- [x] Task C — `tests/test_solution_recap.lua` — Update the test `"win transitions to SolutionRecapScene"` (around line 86): replace the `ctx.sm:update(1.0)` call with a direct `scene:_cmd_activate("continue")` call; keep all other assertions unchanged.

- [x] Task D — `tests/ui/01_solve_puzzle_1.lua` — Update the spec: replace `{ wait_until = { text = "SOLVED!", max_frames = 3000 } }` with `{ wait_until = { status = "win", max_frames = 3000 } }, { click_button = "Continue" }, { assert_text = "SOLVED!" }` (the old `wait_until` was relying on the now-removed auto-transition side-effect).
