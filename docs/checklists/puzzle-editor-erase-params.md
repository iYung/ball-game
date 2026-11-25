## Puzzle Editor Erase & Params Checklist

Design: [docs/design/puzzle-editor-erase-params.md](../design/puzzle-editor-erase-params.md). Testing rules: [docs/testing.md](../testing.md). All open questions are resolved with the recommended answers.

### Waves

| Wave | Tasks | Depends on |
|---|---|---|
| 1 | B and C, in parallel | nothing |
| 2 | A and D, in parallel | C |
| 3 | F | A |
| 4 | E | C, D, F |
| 5 | G | E |
| 6 | H | B, G |

### Rules for every task

- All tasks share one git worktree. Parallel tasks edit different files; do not touch files outside your task. Do not commit.
- When marking your item `[x]`, re-read this file first and change only your own checkbox.
- Never edit an existing test or spec to make it pass. The only legitimate removals are the ones named in task E. Add new specs and tests.
- UI behaviour needs a spec in `tests/ui/` driven by real input (`click_button`, `click_cell`, ...). Calling private methods does not count as UI coverage.
- Every clickable thing is in `ui_elements()` and is hit-tested with `UI.element_at`. Lay out with constants, not `font:getWidth`.
- CI needs 100% line coverage of `lua/game/` (`love . --headless --coverage`, add `--verbose-gaps` to list misses). In parallel waves, run your own test files (`love . --headless <path>`); a failure in the full suite may come from the other agent's half-written files. In sequential waves, and at the end of each wave, the full coverage run must pass. It takes several minutes.
- No README or archive work (verification phase).

### Wave 1

- [x] Task B — `lua/headless/ui_runner.lua`, `tests/test_ui_runner.lua`, `docs/testing.md` — Add element kind `resize`, for thin resize strips drawn on grid cells.
  - `VALID_KINDS` gains `resize`.
  - In `UIRunner.check_invariants`, an overlapping pair is allowed only when one element's kind is `resize` and the other's is `cell` (either list order). Every other overlap still fails, including `resize`/`resize`, `resize`/`button` and `resize`/`slot`. Skip allowed pairs inside the sweep, so that a later disallowed pair is still found and the "smallest i, then smallest j" reporting holds. The well-formed, duplicate-id and off-screen checks apply to `resize` unchanged.
  - Add cases to `tests/test_ui_runner.lua` for each of the above, including a list with an allowed pair plus a disallowed pair.
  - In `docs/testing.md`: add `resize` to the kind list (Entry shape and invariant 1), state the exception in invariant 3, and rewrite "Known gap: resize strips are not in the registry". The puzzle scene's strips remain unregistered. The puzzle editor registers its strips as kind `resize` with id `resize:<ax>,<ay>:<action>` (anchor cell; action `grow_col`, `shrink_col`, `grow_row` or `shrink_row`), label `+` or `-`, listed before the grid cells. Add that row to the id table. Because labels `+`/`-` repeat, specs select strips by id. (Task H implements the editor side.)

- [x] Task C — `lua/game/op_tiles.lua` (new), `lua/game/scenes/matrix_scene.lua`, `tests/test_op_tiles.lua` (new) — Move op tile symbols, default params, param limits, click handling and cell drawing into a shared module, and make `MatrixScene` delegate to it with **no behaviour change**. The editor will use the same functions. All existing tests and specs (notably `tests/ui/08_matrix_scene_ops.lua`) must pass unmodified.
  - Interface (`local OpTiles = require("lua/game/op_tiles")`); the module keeps no mutable state:
    - `OpTiles.SYMBOLS` — the current `OP_SYMBOLS` table of `matrix_scene.lua`.
    - `OpTiles.default_params(op)` — a fresh copy of the current `DEFAULT_PARAMS[op]`, or `{}` (no entry for `set_col`; do not add one here).
    - `limits` — a table `{ rows = n, cols = m, set_row = k }`: the upper bounds for row params, column params and the `set_row` row.
    - `OpTiles.param_defs(op, limits)` — a fresh array of `{key, label, min, max}` in the order of the current `PARAM_DEFS`, or nil. `max` is `limits.rows` for `scale_row.row`, `swap_rows.*`, `add_rows.src/dst`; `limits.cols` for `scale_col.col`, `swap_cols.*`, `add_cols.src/dst`, `set_col.col`; `limits.set_row` for `set_row.row`; scalars are -9..9.
    - `OpTiles.click(tile, dc, dr, rel_x, cell_size, limits)` — applies a left click on the tile cell at 0-based offset `(dc, dr)` from the anchor, `rel_x` pixels from that cell's left edge. Returns true when the cell is a parameter or value cell (click consumed, even in the centre third), false otherwise. It ignores `tile.locked` and `tile.fixed`; the caller decides editability. It creates `tile.params` / `tile.values` sub-tables when missing.
    - `OpTiles.draw_cell(tile, dc, dr, sx, sy, cell_size, fonts, editable)` — draws the content of one tile cell (no tile background or border). `fonts = { cell = <font>, ui = <font> }`. `editable = false` gives the dimmed colours and no `-`/`+` marks. Cell `(0,0)` includes what the anchor draws today: centred symbol for ops without anchor params, small top-left symbol plus value for matrix ops, the param cell for `set_row`/`set_col`, band 1 for `scale_row`/`scale_col`, strip 1 for swaps.
    - `OpTiles.draw_overlay(tile, sx, sy, cell_size, fonts)` — the `⇅` / `⇄` mark of swap tiles, positioned from the anchor's top-left as today; call after the cells. No-op for other ops.
  - Click rules, copied from `MatrixScene:_mouse_pressed_inner`: "left third" is `rel_x < cell_size/3` (-1), "right third" is `rel_x >= cell_size*2/3` (+1), centre changes nothing. Matrix ops: every cell is `values[dr+1][dc+1]`. `set_row`: `dc == 0` is `params.row` (limits from `param_defs`), else `values[1][dc]`. `set_col`: `dr == 0` is `params.col`, else `values[dr][1]`. `scale_row` (band `dr+1`) / `scale_col` (band `dc+1`): a non-selected band is selected by any third; on the selected band the thirds change `params.scalar` (fallback 2). Swaps: strip `dr+1` / `dc+1`, range fixed at 1..4 regardless of `limits`, a change that would equal the other index is rejected. Other ops: cells with `dc >= 1` are consumed and edit `param_defs(...)[dc]` if it exists (`scalar_mul`, `add_rows`, `add_cols`); `dc == 0` returns false. Keep the current fallbacks for nil params (`or 1`, `or 2`, `or 0`).
  - Every change clamps to both bounds, `max(min, min(max, v + delta))`, with values and scalars -9..9. This equals today's behaviour for in-range tiles and brings an out-of-range value into range on the next `-`/`+`.
  - `MatrixScene`: remove the module-level `PARAM_DEFS` and its mutation in `load_puzzle`; build limits per instance as `{ rows = puzzle.input.rows, cols = puzzle.input.cols, set_row = 4 }` (`set_row = 4` preserves current game behaviour: `load_puzzle` never lowers it). Take `OP_SYMBOLS` and default params from the module. In `_mouse_pressed_inner`, keep the `fixed`/`locked` early return, then `if OpTiles.click(...) then return end` and fall through to the existing palette-apply code (which only acts on anchor cells).
  - Drawing: keep the two-pass grid walk, `draw_tile` and `draw_ref_cell`, which call `draw_cell` / `draw_overlay` for the same cells as today (the grid footprint and `op_width`/`op_height` differ for some tiles; do not "fix" that). The per-op `draw_*` helpers may be removed if nothing in `tests/` references them. `_place_tile_at`, `_resize_tile`, `_expand_rects`, footprints and resize strips stay unchanged.
  - Tests: unit tests for `param_defs`, every click branch (both thirds, centre, clamping from out of range, swap rejection, missing tables, false returns) and `draw_cell` editable vs not for every op (assert with `Stubs.drawn_text()`).

### Wave 2

- [x] Task A — `lua/game/scenes/editor_scene.lua`, `lua/game/scenes/matrix_scene.lua`, `tests/ui/12_editor.lua`, `tests/test_editor_pushers.lua` (new) — Fix the crash when pressing Test with a pusher placed. The def has no pusher `id` and `MatrixScene.load_puzzle` does not copy one (errors at `_pusher_list` sort with two pushers, and when drawing with one).
  - `load_puzzle`: add `id = t.id` to the tile built from a `locked` entry.
  - Editor placement: give a new pusher the lowest id 1..8 (letters A-H) not used by a pusher on the grid; refuse a ninth. Remove `_pusher_count`, so erased ids are reused.
  - `_build_def` and `_serialize` write `id` for pusher entries.
  - `_load_def`: keep valid explicit ids (integer 1..8, first occurrence). Then give pushers with a missing, invalid or duplicate id the lowest free one (reserve all explicit ids first); skip a pusher when none is free.
  - Specs: place one pusher, Test, see the puzzle scene (`psel:A`), Menu back; place two pushers, Test, `psel:A` and `psel:B` visible; Copy, erase, Paste, Test still shows both; paste text with pushers without ids, then Test.
  - Unit test: the 8 limit, id reuse after erase, import id assignment, and the `id=` text in `_serialize` output.

- [x] Task D — `lua/game/op_tiles.lua`, `tests/test_op_tiles_model.lua` (new) — Add the editor's tile model to the shared module (after Task C). `MatrixScene` does **not** use these functions.
  - `OpTiles.footprint(op, tile_rows, tile_cols)` returns `w, h` (cols, rows): `scalar_mul` 2x1; `scale_row` 1x(`tile_rows` or 4); `scale_col` (`tile_cols` or 4)x1; `swap_rows` 1x2; `swap_cols` 2x1; `add_rows`, `add_cols` 4x1; `set_row` (1+(`tile_cols` or 1))x1; `set_col` 1x(1+(`tile_rows` or 1)); `add_matrix`, `sub_matrix`, `mul_matrix` (`tile_cols` or 1)x(`tile_rows` or 1); all others 1x1.
  - `OpTiles.new_tile(op, input_rows)` returns a fresh `{ kind="op", op=op, locked=true, params=..., values=..., tile_rows=..., tile_cols=..., width=w, height=h }`. Params are `default_params(op)`, plus `{col=1}` for `set_col`. Sizes: matrix ops `tile_rows=1, tile_cols=1`; `scale_row` `tile_rows=4`; `scale_col` `tile_cols=4`; `set_row` `tile_cols=1`; `set_col` `tile_rows=input_rows`; others none. Values only for: `add_matrix`/`sub_matrix` `{{0}}`, `mul_matrix` `{{1}}`, `set_row` `{{0}}`, `set_col` `input_rows` rows of `{0}`.
  - `OpTiles.tile_from_def(entry)` returns the same shape for an imported `kind="op"` entry, filled with runtime behaviour, not new-tile defaults: missing sizes are 1 (`tile_rows` for matrix ops and `set_col`, `tile_cols` for matrix ops and `set_row`), except `scale_row` `tile_rows=4` and `scale_col` `tile_cols=4`; given `tile_rows`/`tile_cols` are preserved on any op. Missing params: indices 1, second index (`row_b`, `col_b`, `dst`) 2, scalar 1, per the op's keys, including `set_col.col=1`. Missing value cells inside the tile size are 0, also for `mul_matrix`. Given values (out of range, or beyond the size) are kept. `params` and `values` are deep copies. Explicit `entry.width` / `entry.height` win over `footprint`.
  - `OpTiles.resize_actions(tile)` returns an ordered array drawn from `grow_col, shrink_col, grow_row, shrink_row` (that order): rows resizable for `scale_row`, `set_col` and matrix ops; cols for `scale_col`, `set_row` and matrix ops; grow only below 4, shrink only above 1. It ignores `locked`; grid space is the caller's check.
  - `OpTiles.resize(tile, action)` returns false if the action is not in `resize_actions`; otherwise changes `tile_rows`/`tile_cols` by 1, sets `width`/`height` from `footprint`, fills new value cells (1 for `mul_matrix`, else 0, overwriting stale entries), removes values beyond the new size on shrink, clamps `params.row` (`scale_row`) / `params.col` (`scale_col`) to the new size, and returns true. It does not touch any grid.
  - Tests: every row of the footprint list, new tiles, import filling and copy independence, every resize action per resizable op including limits, and that `Sim.apply_op` accepts new tiles (a new `mul_matrix` leaves value (1,1) unchanged).

### Wave 3

- [x] Task F — `lua/game/scenes/editor_scene.lua`, `tests/ui/12_editor.lua` — Make all 23 palette buttons visible. Today `_layout_palette` silently drops any button past x = 810, hiding `add_cols`, `set_col`, `rotate_90`, `flip_h`, `flip_v`, `abs` and erase.
  - One row at y = `BAR_BTN_Y`, within x 10..810: for example 30px buttons, 3px gap, 6px extra at each of the 3 separators, erase button 48px wide.
  - Rename the erase button label to `Erase`; keep id `editor:pal:erase` and the selected highlight. Check labels such as `<>R` and `R90` still fit.
  - Remove the overflow filter, so an overflow fails the layout invariant.
  - Specs: `assert_button visible = true` for all 23 ids (SRC, SNK, GAP, P, 18 ops, Erase); select Erase by clicking the label `Erase` and assert selected; select and place `set_col` and `abs`. (Erasing with left click on param tiles is Task E.)
  - Note in your report that rendering needs a manual check.

### Wave 4

- [x] Task E — `lua/game/scenes/editor_scene.lua`, delete `lua/game/param_popup.lua` and `tests/test_param_popup.lua`, `tests/ui/12_editor.lua` — Remove the popup; edit params and values on the tile; apply the new click rules. Uses `lua/game/op_tiles.lua` (Tasks C, D; read it for the API: `new_tile`, `tile_from_def`, `click`, `draw_cell`, `draw_overlay`, `SYMBOLS`).
  - Remove every `ParamPopup` use (require, `new`, `key_pressed`, `text_input`, `draw`, open).
  - Grid click rules: right click on any cell of a tile erases the whole tile. Left click with Erase selected: erase the whole tile from any cell (source, sink, gap, pusher, op); nothing on empty. Left click otherwise (placement tool or nothing selected): on an occupied cell, if it is an op, call `OpTiles.click(tile, cx-ax, cy-ay, mx - e.rect.x, CELL_SIZE, { rows = input.rows, cols = input.cols, set_row = input.rows })`, else do nothing; on an empty cell, place if a tool is selected. `locked` is ignored.
  - No placement tool overwrites a tile. The sink tool in particular must only place on an empty cell, and must not remove the old sink unless the new one is placed. Moving the sink to an empty cell still clears the old one. Remove branches of `_place_at` that become unreachable.
  - Op placement: build the tile with `OpTiles.new_tile(op, self._input.rows)`; refuse unless all `width`x`height` cells are in bounds and empty. `_load_def`: build op entries with `OpTiles.tile_from_def(t)` (non-op entries keep the current path, including Task A's pusher ids). Remove the editor's `OP_SIZES`, `DEFAULT_PARAMS`, `OP_SYMBOLS` and `deep_copy_params`. Changing the input size or pasting never rewrites stored params.
  - Drawing: keep the tile background and border, then `draw_cell(..., true)` for every cell, then `draw_overlay`. Every tile still shows which op it is: add a small symbol on tiles whose cells do not draw it (`scale_*`, `swap_*`, `set_*`) where it does not collide with cell text (`scale_col` draws `C1` top-left). Remove the lock icon from op tiles.
  - Delete the two specs "click placed op with params opens popup; confirm updates tile" and "param popup: escape cancels without changing params" (they assert removed behaviour; say so in your report). Replace them with specs driven by `click_cell` with `part`: scalar on `scalar_mul` (`×3`); matrix value on `add_matrix`; band select then scalar on `scale_row` and `scale_col`; swap index including the rejected equal value; `add_rows` / `add_cols` cells; `set_row` and `set_col` index (limited by input size, changed live after `editor:input_rows_inc`) and values; a placement tool selected still edits instead of replacing; Erase left click on a non-anchor cell erases a multi-cell param tile; sink tool on a multi-cell tile leaves it intact; a placement that does not fit is refused; no popup text appears. Assert with distinctive drawn text (single digits are weak; drive a value to something like `-3`).

### Wave 5

- [x] Task G — `lua/game/scenes/editor_scene.lua`, `tests/test_editor_roundtrip.lua` (new), `tests/ui/12_editor.lua` — Make Copy, Test and Paste preserve `params`, `values`, `tile_rows`, `tile_cols`, `width`, `height` and pusher `id`.
  - `_build_def` is the single source: add `values` (deep copy) to each locked entry; keep `params`, `tile_rows`, `tile_cols`, `id`, and `width`/`height` when greater than 1.
  - Rewrite `_serialize` to format the table returned by `_build_def()` and nothing else, keeping the current text layout (`name`, grid size, `source`, `sink`, `ops`, `locked`, `gaps`, `input`, `target`; entry keys `kind, op, x, y, id, width, height, tile_rows, tile_cols, params` with sorted keys, `values` as nested braces). With no sink placed both then use `_build_def`'s `{10,10}` (today `_serialize` writes `{1,1}`).
  - Confirm `_load_def` (via `OpTiles.tile_from_def`) restores everything; fix it if not.
  - Unit test: for every op with edited params and values (negative and out-of-range numbers, resized sizes set on the tile), `load(scene:_serialize())()` deep-equals `scene:_build_def()`; loading it into a new `EditorScene` and building again is also equal; mutating a built def does not change the grid; older text without the new fields loads with the runtime fills, including `data/puzzles/23_locked_scale.lua` (footprint from `tile_rows=1`).
  - Specs: edit a scalar and a matrix value, Copy, erase both, Paste, assert the edited text; Test shows the edited values, then Menu returns with the edits intact.

### Wave 6

- [x] Task H — `lua/game/scenes/editor_scene.lua`, `tests/ui/12_editor.lua`, `tests/test_editor_resize.lua` (new) — Add resize strips. Needs Task B (runner kind `resize`) and `OpTiles.resize_actions` / `OpTiles.resize` / `OpTiles.footprint`.
  - For each op anchor, for each action from `resize_actions(tile)`, add `{ id = "resize:<ax>,<ay>:<action>", label = "+" or "-", kind = "resize", rect, enabled = true }`, iterating the grid in y-then-x order and listed **before** the grid cells. No strips while Erase is selected. A grow strip exists only when every newly covered cell (from `tile.width`/`height`: the next column over the tile's height, or the next row under the tile's width) is in bounds and empty.
  - Rects, with `CS = CELL_SIZE`, `(L, T)` the anchor's top-left, `w, h = tile.width, tile.height`, `q = math.floor(CS/4)`:
    - `grow_col`: `x = L + w*CS, y = T, w = CS/3, h = h*CS`
    - `grow_row`: `x = L + CS/3, y = T + h*CS, w = w*CS - CS/3, h = CS/3`
    - `shrink_col`: `x = L + (w-1)*CS + CS*2/3, y = T, w = CS/3, h = q`
    - `shrink_row`: `x = L + CS/3, y = T + h*CS - q, w = CS/3, h = q`
  - `mouse_pressed` resolves through `UI.element_at`. Left click on a strip: clear the old footprint, `OpTiles.resize`, re-place with `Grid:set_multi_2d`. Right click on a strip: erase the tile in the cell underneath (computed from the click position).
  - Draw strips over the tiles from the same registry entries (green `+`, red `-`, as in game). The puzzle scene is not changed.
  - Specs (select strips by id): each of the four actions on a matrix op, checking `assert_tile` and cell text; `scale_row`, `scale_col`, `set_row`, `set_col` resize; new `mul_matrix` cells fill 1; shrinking drops values (shrink then grow shows the fill); shrinking a scale tile pulls the selected band inside; no grow strip when blocked by a tile or at the grid edge (`visible = false`); no strips with Erase selected; right click on a grow strip over empty space and on a shrink strip; with a strip present the value `-`/`+` thirds and centre still work; resize, Copy, erase, Paste keeps the size.
  - Unit test: strips never overlap each other for adjacent resizable tiles, and never cover the centre or the `-`/`+` click points (`x + w/6`, `x + 5w/6` at cell mid-height) of any tile cell.
  - Note in your report that rendering needs a manual check with `love .` or the web preview.
