# Coverage Gaps Checklist

Each task is independent and can run in parallel unless noted.

---

- [x] Task 1 — `tests/test_solution_recap.lua` — Add a float-matrix draw test.
  `fmt_num` in `lua/game/hud.lua:20` (`return string.format("%.2f", v)`) is never hit because all test matrices use integers. In `test_solution_recap.lua`, add a new test block that builds a `SolutionRecapScene` whose `frames` table contains a 2×2 matrix with a float value (e.g. `0.5`). Call `scene:draw()`. The debug hook fires on line 20 when `love.graphics.printf(fmt_num(v), ...)` evaluates its argument with `v = 0.5`.

---

- [x] Task 2 — `tests/test_progress.lua` (new file) — Cover `progress.lua` load body and write-error branch.
  Three gaps in `lua/game/progress.lua`:
  1. Lines 42–61 (`_load()` body) — unreachable because `love.filesystem.getInfo("progress.lua")` returns nil in headless (the file doesn't exist on disk). Fix: before requiring the module, swap the stubs so `love.filesystem.getInfo` returns a fake `{type="file"}` and `love.filesystem.read` returns a JSON string of the new save format (`'{"solved":[1,2],"cutscenes":{"1":true}}'`), then `package.loaded["lua/game/progress"] = nil; local Progress = require("lua/game/progress")`, and assert `Progress.solved(1)` and `Progress.solved(2)` return true. Restore stubs afterwards.
  2. Same setup but return an old-format JSON array (`'[1,2]'`) to cover the old-format migration branch in `_load()`.
  3. Line 36 (`_ = err`) — the write-error branch in `_persist()`. Stub `love.filesystem.write` to `error("disk full")`, call `Progress.mark_solved(3)`, assert no Lua error escapes. Restore stub afterwards.

---

- [x] Task 3 — `tests/test_basics.lua` — Cover `Grid:clear()` rightward-ref scan and locked tile guard, and `Grid:get_anchor()` edge cases.
  Three gaps in `lua/game/grid.lua`:
  1. Lines 108–120 (`clear()` rightward-ref scan) — triggered when clearing a cell that has a ref cell to its right with `width = nil`. Add a test that calls `grid:set(5, 1, {kind="op"})`, manually sets `grid.cells[1][6] = {_anchor={x=5,y=1}}` (a fake ref cell), then calls `grid:clear(5, 1)` and asserts `grid.cells[1][6]` is nil.
  2. Line 104 (`clear()` locked-tile guard) — set a locked tile at (3,3) and call `grid:clear(3,3)`; assert tile is still present.
  3. Lines 41, 43–44 (`get_anchor()`) — call `grid:get_anchor(0, 0)` and assert nil (out of bounds); place a multi-cell op and call `get_anchor` on a ref cell to cover the ref-cell return path.

---

- [x] Task 4 — `tests/test_pushers.lua` — Add direct `apply_op` tests for `negate`, `swap_rows`, `scalar_mul`, and `add_matrix`.
  `lua/game/pusher_sim.lua` has ~10 uncovered lines in `Sim.apply_op` for these ops — they are only exercised indirectly through scene play. In the existing `apply_op` test block in `test_pushers.lua`, add one `Sim.apply_op(mat, op_tile)` call per missing op:
  - `negate` on a 2×2 matrix; assert all values negated.
  - `swap_rows` with `params = {row_a=1, row_b=2}` on a 2×2; assert rows swapped.
  - `scalar_mul` with `params = {scalar=3}` on a 2×2; assert all values tripled.
  - `add_matrix` with a 2×2 `values` table on a 2×2 matrix; assert values summed.

---

- [x] Task 5 — `tests/test_cutscene_scene.lua` (new file) — Cover `CutsceneScene.on_enter()` error paths and portrait code paths.
  Three groups in `lua/game/scenes/cutscene_scene.lua`:
  1. Lines 53–55 (`not chunk` path in `on_enter()`): create a `CutsceneScene` with a mock scene_manager that records `switch` calls; stub `love.filesystem.load` to return `nil, "not found"`; call `scene:on_enter()`; assert the mock scene_manager received a `switch` call.
  2. Lines 58–61 (bad data path in `on_enter()`): same setup but stub `love.filesystem.load` to return a function that returns `"bad"` (not a table); assert `switch` called.
  3. Lines 82–114 (`_get_portrait()` and `_draw_portrait()`): stub `love.filesystem.getInfo` to return `{type="file"}` for `assets/portraits/alice.png`; stub `love.graphics.newImage` to return a stub image object with a `:getDimensions()` method (returns `128, 128`); call `scene:_draw_portrait("alice")`; assert no error. Also call with an empty name and assert nil returned (line 83 guard).

---

- [x] Task 6 — `tests/test_game_scene.lua` — Add `draw()` and blink-timer tick coverage.
  `lua/game/scenes/game_scene.lua` lines 44–51 (`draw()`) are never called in tests — the existing tests only call `update`. Lines 38–40 (blink timer branch) require `dt ≥ 0.5`. In `test_game_scene.lua`, add:
  1. A test that calls `scene:draw()` after `scene:on_enter()` and asserts no error.
  2. A test that calls `scene:update(1.0)` (dt=1.0 fires the 0.5s timer) and asserts `coin.visible` has toggled.

---

- [x] Task 7 — `tests/ui/02_level_select_keyboard.lua` and new unit test — Cover `LevelSelectScene` escape and right-click.
  Two gaps in `lua/game/scenes/level_select_scene.lua`:
  1. Lines 151–153 (`key_pressed("escape")`): add a step `{ press = "escape" }` to the end of one spec in `02_level_select_keyboard.lua` and assert the scene changes back to the start screen (e.g. `assert_text` for a string only shown on the start screen, or use `assert_button` for a start-screen button).
  2. Line 158 (`mouse_pressed(_, _, btn ~= 1)` early return): add a unit test in a new block at the end of `tests/test_level_select.lua` (or create `tests/test_level_select.lua` if absent) that calls `scene:mouse_pressed(400, 300, 2)` and asserts no scene switch occurred.

---

- [x] Task 8 — `tests/ui/08_matrix_scene_ops.lua` — Add `scale_row` and `swap_rows` click handler specs.
  Two op click handlers in `lua/game/scenes/matrix_scene.lua` are uncovered: `scale_row` (lines 1989–2005) and `swap_rows` (lines 2007–2024). Add two new specs to `08_matrix_scene_ops.lua`:
  1. **scale_row**: place `scale_row` from the palette (puzzle 1 has no op restriction) at e.g. cell (5,1). It places with `tile_rows=4`. Click cell (5,1) (dr=0 → band=1, which equals default `params.row=1` → scalar branch). Click with `part="left"` to dec scalar. Click with `part="right"` to inc scalar. Then click cell (5,2) (dr=1 → band=2 ≠ params.row=1 → band-select branch). Assert tile still exists.
  2. **swap_rows**: place `swap_rows` from the palette at (5,1). It places with `tile_rows=2`. Click cell (5,1) `part="right"` (strip 1, dr=0 → row_a inc). Click cell (5,2) `part="right"` (strip 2, dr=1 → row_b inc). Assert tile still exists.

---

- [x] Task 9 — `tests/test_matrix_input.lua` (new file) — Cover `MatrixScene` keyboard shortcuts, text_input, mouse_moved, and `_clear_drag`.
  Four gaps in `lua/game/scenes/matrix_scene.lua`:
  1. Lines 2155–2158 (`key_pressed("r")` and `key_pressed("backspace")`): create a `MatrixScene` via `MatrixScene.new(sm, PuzzleLoader.load(1))`; call `scene:key_pressed("r")`; assert `scene.running == true` (or that `_cmd_activate("run")` fired). Call `scene:key_pressed("backspace")`; assert running stopped / matrix reset. Use a mock scene_manager stub as in other unit tests.
  2. Line 2167 (`text_input(_)` empty function): call `scene:text_input("a")`; assert no error (just exercises the line).
  3. Lines 1840–1850 (`mouse_moved` body when drag active): set `scene._drag_tile = {kind="pusher", id=1, width=1, height=1}`; call `scene:mouse_moved(mx_in_grid, my_in_grid)` using a coordinate inside the grid panel; assert `scene._drag_ghost` was set. Also call `scene:mouse_moved(0, 0)` (outside grid) and assert `scene._drag_ghost` is nil.
  4. Lines 448–461 (`_clear_drag` restore path): set `scene._drag_tile = {kind="pusher", id=1}`, `scene._drag_origin = {x=5, y=5}`, `scene._drag_ghost = {cx=5, cy=5}`; call `scene:_clear_drag()`; assert `scene.grid:get(5,5)` returns the tile and `scene._drag_tile` is nil.

---

- [x] Task 10 — `tests/test_matrix_draw.lua` (new file) — Cover `_draw_status_banner`, ghost preview, `-col`/`-row` affordances, and `_timeline_element_click`.
  Four draw/interaction paths in `lua/game/scenes/matrix_scene.lua`:
  1. Lines 1664–1675 (`_draw_status_banner`): create a scene, set `scene.status = "win"`, call `scene:draw()`; assert no error. `love.graphics.*` are no-ops in headless so this just fires the lines.
  2. Lines 848–883 (ghost preview in `draw_grid`): set `scene._drag_tile = {kind="pusher", id=1, width=1, height=1}`, `scene._drag_ghost = {cx=5, cy=1}`; call `scene:draw_grid()`; assert no error.
  3. Lines 803–814 and 829–840 (`-col` and `-row` affordance draw): place an `add_matrix` op tile at (5,1) via `scene:_place_tile_at(5,1,{kind="op",op="add_matrix"})`, then resize it to 2 cols via `scene:_resize_tile(5,1,"grow_col")` and 2 rows via `scene:_resize_tile(5,1,"grow_row")`; call `scene:draw_grid()`; assert that `scene._expand_rects` contains entries with `action="shrink_col"` and `action="shrink_row"`.
  4. Lines 1649–1662 (`_timeline_element_click` for `tl:` and `slot` elements): call `scene:_timeline_element_click({id="tl:inc", kind="tl", enabled=true}, 1)` and `scene:_timeline_element_click({id="slot:A:1", kind="slot", enabled=true}, 1)`; assert no error.

---

- [x] Task 11 — `tests/test_recap_buttons.lua` — Add missing coverage for `SolutionRecapScene` input methods and float draw.
  Four gaps in `lua/game/scenes/solution_recap_scene.lua`:
  1. Lines 394–401 (`key_pressed`): call `scene:key_pressed("return")`, `scene:key_pressed("r")`, `scene:key_pressed("escape")` on a scene with a mock scene_manager; assert the correct scene switches happen.
  2. Line 406 (`mouse_pressed(_, _, btn ~= 1)` early return): call `scene:mouse_pressed(400, 400, 2)`; assert no scene switch.
  3. Line 413 (`text_input(_)` empty function): call `scene:text_input("x")`; assert no error.
  4. Line 231 (float branch in `SolutionRecapScene:_draw_matrix()`): build a recap scene whose `frames` include a matrix with a float value (e.g. `0.5`); call `scene:draw()`; assert no error.

---

- [x] Task 12 — `tests/ui/05_start_screen.lua` — Cover `StartScene.key_pressed("d")` (unlock-all shortcut).
  Lines 54–55 in `lua/game/scenes/start_scene.lua` (`self:_unlock_all(); return`) are never hit because no test presses `"d"`. Add a step `{ press = "d" }` to the end of one spec in `05_start_screen.lua` and assert that world 2 is now accessible (e.g. by clicking the level-select button and asserting a world 2 puzzle appears, or by asserting a world-2 button is no longer disabled).
