# Design: game-coverage-100pct

## Goal

Bring every `lua/game/` file to 100 % line coverage as reported by
`love . --headless --coverage`, by adding targeted unit tests and UI specs.

Baseline (all 27 existing tests passing):

| File | Hit/Exec | % |
|---|---|---|
| grid.lua | 81/83 | 97 % |
| player.lua | 14/28 | 50 % |
| progress.lua | 67/78 | 85 % |
| pusher_sim.lua | 109/131 | 83 % |
| puzzle_loader.lua | 34/54 | 62 % |
| param_popup.lua | 0/131 | 0 % |
| scenes/cutscene_scene.lua | 0/145 | 0 % |
| scenes/game_scene.lua | 18/36 | 50 % |
| scenes/level_select_scene.lua | 183/187 | 97 % |
| scenes/matrix_scene.lua | 1157/1537 | 75 % |
| scenes/solution_recap_scene.lua | 255/285 | 89 % |

Files already at 100 % (hud, matrix_math, palette, start_scene) are not touched.

---

## Affected files

New test files:
- `tests/test_param_popup.lua`
- `tests/test_game_scene.lua`
- `tests/ui/06_cutscene.lua`
- `tests/ui/07_drag_drop.lua`
- `tests/ui/08_matrix_scene_ops.lua`

Extended/updated test files:
- `tests/test_progress.lua` — add _load old-format and _persist error paths
- `tests/test_pushers.lua` — add remaining apply_op branches
- `tests/test_pusher_scene.lua` — add timeout status path
- `tests/test_world_select.lua` / `tests/test_puzzle_loader.lua` — add PuzzleLoader error paths
- `tests/test_scene.lua` / `tests/test_basics.lua` — add Grid.clear_all locked-tile path

No existing test assertions are changed.

---

## What changes

### param_popup.lua (0 % → 100 %)

`ParamPopup` is never imported by any other module — it is currently dead
code with no game path that loads it. A standalone unit test is the only
way to cover it.

`tests/test_param_popup.lua` (new, unit test):
- `ParamPopup.new()` / `is_open()` / `close()`
- `open()` with every op type in FIELD_DEFS (scale_row, add_rows, swap_rows,
  scalar_mul, transpose, negate)
- `key_pressed` for escape (cancel callback fired), return/kpenter
  (confirm fires), tab (focus cycles), backspace (deletes last char)
- `text_input` appends to current field
- `_try_confirm` happy path (valid int, valid num → confirm callback)
- `_try_confirm` error paths: non-numeric input, float-for-int
- `draw()` while open with 0 fields (transpose/negate) and with fields
- `draw()` with `_error` set

Rule: `draw()` runs in headless mode (love.graphics stubs are no-ops) so
all draw branches are reachable.

### player.lua (50 % → 100 %)

`tests/test_game_scene.lua` (new, unit test):
- Build `Player.new(0, 0)` — this exercises the constructor.
- Call `player:centre()` — covers the method.
- Call `player:draw()` — covers the draw stub.
- For `player:update(dt)` — HeadlessInput does not expose LÖVE's
  keyboard state, so we set `love.keyboard.isDown` to return true once
  for each direction and call `update(1/60)`.

Rule: Player.input is a `lua/core/input.lua` Input, not HeadlessInput.
  `love.keyboard.isDown` is already stubbed as `return false`.
  To hit the four movement branches, temporarily replace it with a
  closure that returns true for one key name and call update four times.

### progress.lua (85 % → ~93 %)

The uncovered lines are inside `_load()` after a successful file read
(lines 44–62) and the error branch of `pcall` in `_persist()` (lines
33–35). Both are gated by `love.filesystem` behaviour:

- `love.filesystem.getInfo` → returns nil in headless → `_load` returns
  early at line 41 — the data-processing code (lines 44–62) is **never
  reached in headless mode**.
- `love.filesystem.write` → no-op stub → pcall always succeeds → the
  `_ = err` branch (line 35) is never reached.

These lines are infrastructure-unreachable in the headless harness. They
are covered by the real-game save/load path, which cannot run headlessly.
Target for this feature is "as close to 100 % as the headless harness
allows", which excludes these ~11 filesystem-gated lines.

The old-format `_load` branch (lines 58–61) is also behind getInfo and
therefore also unreachable. Document this as a known gap.

### pusher_sim.lua (83 % → 100 %)

Gaps: the `sign()` helper (defined but never called — dead code), the
`sub_matrix`, `mul_matrix`, `set_row` branches of `apply_op`, the
`add_rows`/`add_cols` src==dst shortcut, and the `add_rows`/`add_cols`
branches in apply_op for some edge cases.

`tests/test_pushers.lua` additions (unit tests):
- `apply_op` for `sub_matrix`, `mul_matrix`, `set_row` (not yet tested)
- `add_rows` with src == dst (should return matrix unchanged)
- `add_cols` with src == dst
- `sign` via a direct call or by removing the dead-code designation

Rule: `sign()` is never called by anything in the codebase — it is dead
code from an earlier design. Rather than add a contrived call, the
correct fix is to delete it. If deleted, it no longer appears as an
uncovered line. This is a cleanup, not a new test.

### puzzle_loader.lua (62 % → 100 %)

Uncovered: the error paths in `load(n)` (out-of-range n, failed
filesystem.load) and `world(w)` (out-of-range w).

`tests/test_puzzle_loader.lua` or additions to existing world tests:
- `PuzzleLoader.load(0)` → pcall expects error
- `PuzzleLoader.load(999)` → pcall expects error
- `PuzzleLoader.world(0)` → pcall expects error
- `PuzzleLoader.world(999)` → pcall expects error
- Stub `love.filesystem.load` to return nil for a path → `load()` hits
  the "could not load" error branch

The last one requires temporarily replacing `love.filesystem.load` with a
stub that returns `nil, "injected error"`.

Rule: These are error paths the caller can reach with bad input; pcall
wrapping in the test is correct (not suppression of real errors).

### cutscene_scene.lua (0 % → 100 %)

No existing spec navigates to world 2 for the first time, so the cutscene
path in `_cycle_world` never fires.

`tests/ui/06_cutscene.lua` (new UI spec) with two specs:

**Spec 1: "navigate to world 2 triggers cutscene"**
- `given = { solved = {1,2,3,4,5} }` (world 1 complete)
- Press return → level select
- Press right → `_cycle_world(1)` fires; world 2 is unlocked, cutscene
  not yet seen → `CutsceneScene` is loaded
- `assert_text` for the first beat's speaker name ("SYSTEM")
- Press return → advance to beat 2
- Press return → advance to beat 3
- Press return → advance past final beat → back to level select

This covers: `on_enter`, `_advance`, `update`, `draw`, `key_pressed`
(return/space/escape paths), `mouse_pressed`.

**Spec 2: "escape skips cutscene"**
- Same setup. After entering the cutscene, press escape → back to level
  select immediately.

The `_get_portrait` and `_draw_portrait` placeholder branches are covered
when the headless stubs return nil for `love.filesystem.getInfo(path)` →
`_portrait_cache[name] = false`, then the code-drawn placeholder executes.

Rule: `love.filesystem.load` works in headless for real data files, so
`data/cutscenes/world_2.lua` loads correctly.

### game_scene.lua (50 % → 100 %)

`tests/test_game_scene.lua` (same file as player coverage above):
- `runner.setup` with `GameScene.new()` as factory
- `runner.tick(ctx.input, ctx.sm, 2)` — exercises `on_enter`, `update`,
  `draw`

Rule: GameScene is a prototype/legacy scene not in the puzzle flow.
Player.new calls `love.graphics.newImage` which the headless stub handles.
Input.new calls `love.keyboard` which is stubbed.

### level_select_scene.lua (97 % → 100 %)

Uncovered: "left" key in `key_pressed` (line 143), "u" key (line 149),
and the cutscene-trigger branch of `_cycle_world` (covered by spec 06
above).

Extend `tests/ui/02_level_select_keyboard.lua` or add steps to
`06_cutscene.lua`:
- Press left → cycles world backward — needs `given = {solved = "all"}`
  so world 5 is reachable.
- Press "u" in level select → `Progress.unlock_world` fires.

Rule: "u" is a debug key; exercising it in a UI spec is correct since it
is a real key press routed through the registry/key_pressed.

### matrix_scene.lua (75 % → ~95 %+)

The ~380 uncovered lines fall into these groups:

**A. Drag/drop tool (Mv)** — `_drag_tile`, `mouse_moved` drag branch,
`mouse_released` valid/invalid drop, ghost preview in `draw_grid`.

`tests/ui/07_drag_drop.lua` (new UI spec):
- Open puzzle 1
- Select Mv palette button
- Right-click a grid cell to pick up (via `right_click_cell` → no, drag
  is left-click on Mv mode). Use `click_button = "Mv"`, then
  `click_cell = {cx, cy}` to pick up, `move_mouse`, `click_cell` to drop.

Rule: Per docs, the spec must route through registry. Drag pickup is a
left-click in drag mode; mouse_moved is `move_mouse`.

**B. Op-specific param cell clicks** (add_matrix/sub_matrix/mul_matrix
value cells, set_row row selector and value cells, scale_row band select
and scalar, swap_rows strip delta, scale_col, swap_cols, set_col param
and value cells, scalar_mul ref cell via is_r).

`tests/ui/08_matrix_scene_ops.lua` (new UI spec):
- Open puzzles that have or allow each of these ops. Place the op tile.
- `click_cell` with part="left"|"right" to dec/inc parameters.
- Cover each distinct op handler branch.

This spec is necessarily long but each step is a simple click.

**C. Timeout status** — `sim.tick >= MAX_TICKS` (500).

`tests/test_pusher_scene.lua` addition:
- Set `timeline_n = 1` and configure a pusher that never reaches the
  sink. `runner.fast_forward_until` until `scene.status == "timeout"`.

Actually, MAX_TICKS = 500 and each `do_step` call advances one tick, so
calling `do_step` 501 times directly is clean. Add a unit test case.

**D. `_process_footprint` fail path** — op shrinks matrix so it no longer
fits in the grid. Already tested in `test_pusher_scene.lua` for the
"blocked pusher matrix-at-wall" case. Check whether the specific
_process_footprint fail branch (lines 570–576) is hit.

**E. Remaining draw helpers**: `draw_set_col_value_cell`,
`draw_scale_col_band` (selected branch), `draw_swap_col_strip` (immutable
branch) — these are covered when the corresponding ops are placed on the
board (spec 08 above).

**F. `_place_tile_at` with `spec.kind == "arrow"`** — line 1668 sets
`w=1; h=1` for arrow kind. This kind is not in PALETTE_BUTTONS. It is
dead code from an earlier design. Same handling as `sign()` in
pusher_sim: delete the dead branch to remove the uncovered line.

**G. `mouse_released` invalid-drop path** — ghost position occupied →
falls through to `_clear_drag`. Covered by spec 07 when a drag is dropped
onto an occupied cell.

Overall target: ~95 %+ (some lines inside pure-draw helpers may remain
unreachable until a puzzle that places every op is solved end-to-end).

### solution_recap_scene.lua (89 % → 100 %)

Uncovered: the `_holding` loop-back path (after `_end_hold <= 0` the
animation rewinds to frame 1) and specific draw helpers for op tiles not
present in puzzle 1.

`tests/test_solution_recap.lua` additions:
- After constructing a SolutionRecapScene with a known `_run_frames` list,
  call `update` enough times to advance past the last frame, trigger
  `_holding = true`, then continue ticking until `_end_hold <= 0` →
  loop restarts (`_frame_idx = 1`).

The draw helpers for ops other than the basic pusher path are covered when
spec 08 runs those ops through a full solve cycle.

### grid.lua (97 % → 100 %)

The 2 uncovered lines are in `clear()`: the while-loop that scans
rightward for trailing ref cells when `tile.width` is not set (lines
111–119), and the `tile == nil or tile.locked then return` guard at
line 104.

`tests/test_basics.lua` or `tests/test_scene.lua` additions:
- Build a Grid, place a tile without a `.width` field (set width=nil),
  place a ref cell to its right manually, then call `clear(ax, ay)` →
  the scan finds the ref.
- Call `grid:clear(ax, ay)` on a locked tile → returns without clearing.

---

## What stays the same

- All 27 existing tests and their assertions are unchanged.
- `lua/core/` files are not targeted (user confirmed: "we don't care
  about /core code coverage").
- The `--coverage` flag and `lua/headless/coverage.lua` already exist and
  work; no changes to the coverage tooling are needed.
- The headless harness, stubs, and runner are not modified.

---

## Open questions

None. The user confirmed scope is `lua/game/` only, existing tests must
not be changed, and headless-unreachable lines (filesystem save/load)
are acceptable gaps.
