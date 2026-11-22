# Coverage Gaps

## Goal

Bring every file under `lua/game/` to 100% line coverage so that CI passes.
The enforcement was added in the previous PR (`feat: enforce 100% line coverage in CI`).
The accurate dynamic measurement now exposes real gaps that the old static-text heuristic
did not detect.

## Affected files

| File | Hit/Exec | Cov% | Uncovered |
|------|----------|------|-----------|
| `lua/game/hud.lua` | 77/78 | 98% | 1 |
| `lua/game/progress.lua` | 71/86 | 82% | 15 |
| `lua/game/grid.lua` | 83/96 | 86% | 13 |
| `lua/game/pusher_sim.lua` | 124/134 | 92% | 10 |
| `lua/game/scenes/cutscene_scene.lua` | 138/151 | 91% | 13 |
| `lua/game/scenes/game_scene.lua` | 33/40 | 82% | 7 |
| `lua/game/scenes/level_select_scene.lua` | 195/199 | 97% | 4 |
| `lua/game/scenes/matrix_scene.lua` | 1505/1603 | 93% | 98 |
| `lua/game/scenes/solution_recap_scene.lua` | 279/295 | 94% | 16 |
| `lua/game/scenes/start_scene.lua` | 69/71 | 97% | 2 |
| **TOTAL** | **2955/3134** | **94%** | **179** |

## What changes

Each file gets new test coverage (new test functions inside existing files, or a new spec
in an existing UI spec file). No game code changes — only tests are added, except where
dead code can be deleted.

### hud.lua — 1 line
`fmt_num` has an integer branch (always taken in tests) and a float branch
(`return string.format("%.2f", v)`) that is never hit because all test matrices use
integers. Fix: add a test case that places a float in the matrix (e.g. via `scale_row`
with a non-integer result) and verifies the HUD renders without error.

### progress.lua — ~16 lines
Two gaps:
1. `_load()` body lines 42–61 are unreachable in headless: `love.filesystem.getInfo`
   finds no save file and returns nil, causing an early return at line 41. The fix is to
   add a test that swaps the filesystem stubs before un-requiring and re-requiring the
   module, so `_load()` runs with a mock save file. The test must cover both the new
   format (`{solved={...},cutscenes={...}}`) and the old array format.
2. `_persist()` error branch (line 36: `_ = err`) is never hit because the write stub
   always succeeds. Fix: temporarily stub `love.filesystem.write` to `error()`, call
   `Progress.mark_solved(n)`, then restore.

### grid.lua — ~13 lines
The rightward-ref scan inside `Grid:clear()` (lines 108–120) requires a tile placed
with `width=nil` and a ref cell manually appended to its right. The locked-tile guard
(line 104) requires a locked tile. Additionally `Grid:get_anchor()` has an out-of-bounds
path (line 41) and a ref-cell path (lines 43–44) that may not be hit via scene tests.
Fix: add direct unit tests in `tests/test_basics.lua` for these edge cases.

### pusher_sim.lua — ~10 lines
`Sim.apply_op` does not directly test `negate`, `swap_rows`, `scalar_mul`, or
`add_matrix` via `test_pushers.lua`'s `apply_op` block (they are covered only
indirectly through scene play). The fix is to add explicit `apply_op` test cases for
each missing op in `tests/test_pushers.lua`. Also check if `Sim.blocked()` and
`Sim.footprint_clear()` have any nil-pushers paths that need coverage.

### cutscene_scene.lua — ~13 lines
Two groups of gaps:
1. Error paths in `on_enter()`: line 53–55 (`if not chunk` / file not found) and
   lines 58–61 (bad data). These require the puzzle's cutscene file to be absent or
   malformed. Fix: add steps to `tests/ui/06_cutscene.lua` or a new unit test that
   stubs `love.filesystem.load` to return nil/error.
2. Portrait loading path (`_get_portrait()` lines 88–92 and `_draw_portrait()` lines
   99–107): these execute only if a portrait file exists. No portraits directory is
   present. Fix: either stub `love.filesystem.getInfo` to report a portrait file and
   stub `love.graphics.newImage` to return a stub image, or add a minimal placeholder
   portrait to the data directory.

### game_scene.lua — ~7 lines
`draw()` (lines 45–50) is never called in tests — `runner.tick` only calls `update`.
Timer blink branch (lines 38–40) requires the 0.5 s timer to fire, which needs `dt=1.0`.
Fix: extend `tests/test_game_scene.lua` to call `ctx.sm:draw()` and to call
`runner.tick(ctx, 1.0)` so the timer fires.

### level_select_scene.lua — ~4 lines
Two gaps:
1. `key_pressed("escape")` body (lines 151–153): no test presses Escape on the level
   select screen. Fix: add a spec step `{press = "escape"}` in
   `tests/ui/02_level_select_keyboard.lua`.
2. `mouse_pressed(_, _, btn ~= 1)` early return (line 158): no test right-clicks. Fix:
   add a unit test that calls `ctx.sm:mouse_pressed(x, y, 2)` and asserts no scene
   change.

### matrix_scene.lua — ~98 lines
The largest gap. Known uncovered areas include:
- `key_pressed("r")` and `key_pressed("backspace")` bodies (keyboard shortcuts for
  Run/Reset) — only Escape is tested via keyboard in the sweep test.
- `on_exit()` body — confirm it is called when pressing escape (sweep test covers this).
- `_place_tile_at()` branches for certain spec kinds.
- Op-specific click handlers for ops not covered in `08_matrix_scene_ops.lua`:
  `scale_row` (already-selected band dec/inc), `swap_rows` strip clicks, `add_rows`.
- `_resize_tile()` branches for grow/shrink edge cases.
- `mouse_released()` drag drop to occupied cell.
- `text_input(_)` empty function (1 line).
- Various draw branches for op types not present in sweep puzzles.
Fix: run the coverage tool with verbose per-line output (or add a diagnostic pass) to
identify exact lines, then add targeted UI spec steps in
`tests/ui/08_matrix_scene_ops.lua` and/or `tests/ui/07_drag_drop.lua` for the
interaction gaps, plus direct unit tests in `tests/test_matrix_registry.lua` or a new
file for keyboard shortcut paths.

### solution_recap_scene.lua — ~16 lines
`key_pressed` is never called on the recap scene (all tests use mouse clicks). Fix: add
unit tests that call `recap:key_pressed("return")`, `recap:key_pressed("r")`, and
`recap:key_pressed("escape")` with a mock scene_manager. Also add a test for
`mouse_pressed(x, y, 2)` (non-left-click early return) and `text_input(_)`. The float
draw branch in `_draw_matrix()` (line 231) requires a matrix with non-integer values.

### start_scene.lua — ~2 lines
`key_pressed("d")` body (lines 54–55: `self:_unlock_all(); return`) is not tested.
Fix: add a spec step `{press = "d"}` in `tests/ui/05_start_screen.lua` and assert
world 2 becomes unlocked.

## What stays the same

- No game logic is changed.
- Existing test assertions are not modified.
- Files already at 100% are not touched.

## Open questions

None — the approach is clear for each file. The exact line numbers for `matrix_scene.lua`
will be confirmed from the coverage tool output before the checklist is written.
