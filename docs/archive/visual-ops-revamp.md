# Visual Ops Revamp Checklist

Covers five design docs:
- `docs/design/visual-matrix-add-tile.md` — +M (add_matrix)
- `docs/design/matrix-constant-ops.md` — −M (sub_matrix), ×M (mul_matrix)
- `docs/design/set-row-op.md` — =R (set_row)
- `docs/design/scale-row-visual.md` — ×Rn scale_row visual revamp
- `docs/design/swap-rows-visual.md` — ⇅R swap_rows visual revamp

Execution order: Tasks 1–3 run in parallel. Task 4 runs after all three complete. Tasks 5–6 run in parallel after Task 2 completes.

---

- [x] Task 1 — `game/grid.lua` — Extend Grid to support 2D footprints. Add `Grid:in_bounds_multi_2d(ax, ay, width, height)` returns true when both `(ax,ay)` and `(ax+width-1, ay+height-1)` are in bounds. Add `Grid:set_multi_2d(ax, ay, tile, width, height)` — places tile at anchor; for every `(dx,dy)` where `dx ∈ 0..width-1` and `dy ∈ 0..height-1` and `(dx,dy) ≠ (0,0)`, places `{ref=true, ax=ax, ay=ay}` at `(ax+dx, ay+dy)`. Update `Grid:clear(x, y)` — after resolving to anchor and reading `tile.width`, also read `tile.height` (default 1); wipe every cell in the `width × height` region `(ax..ax+width-1, ay..ay+height-1)`. Existing `Grid:set_multi`, `get`, `is_ref`, `get_anchor`, `clear_all`, `in_bounds_multi` are unchanged.

- [x] Task 2 — `game/matrix_math.lua` — Add four new methods. `Matrix:add_matrix(other)` — element-wise addition, clamped to overlapping rows/cols. `Matrix:sub_matrix(other)` — element-wise subtraction, same clamping. `Matrix:mul_matrix(other)` — element-wise multiplication, same clamping. `Matrix:set_row(r, values)` — if `r` is out of range return a copy unchanged; otherwise copy the matrix and for `c = 1..min(self.cols, #values)` set `m.values[r][c] = values[c]`; return the modified copy.

- [x] Task 3 — `game/cursor.lua` — Add four new cases to `apply_op`. Read `game/cursor.lua` first to find the existing `if tile.op == …` chain. Add after the last existing case: `add_matrix` — build `Matrix.new(tile.tile_rows or 1, tile.tile_cols or 1, tile.values)` and return `mat:add_matrix(addend)`. `sub_matrix` — same build, return `mat:sub_matrix(operand)`. `mul_matrix` — same build, return `mat:mul_matrix(factor)`. `set_row` — read `row = (tile.params or {}).row or 1`; build `values` table from `tile.values[1]` for `c=1..tile.tile_cols or 1`; return `mat:set_row(row, values)`. Require Matrix at the top of cursor.lua if not already present.

- [x] Task 4 — `game/scenes/matrix_scene.lua` — Full scene update for all new ops. Read the current file first. Make ALL of the following changes in one pass:

  **Constants:**
  - Replace `OP_WIDTHS` table with `OP_SIZES` table (key → `{cols, rows}`): `transpose={1,1}`, `negate={1,1}`, `scalar_mul={2,1}`, `scale_row={1,4}`, `swap_rows={1,2}`, `add_matrix={1,1}`, `sub_matrix={1,1}`, `mul_matrix={1,1}`, `set_row={2,1}`. Remove `add_rows` entirely.
  - Add helpers at the top: `local function op_width(op) return (OP_SIZES[op] or {1,1})[1] end` and `local function op_height(op) return (OP_SIZES[op] or {1,1})[2] end`.
  - Update `OP_SYMBOLS`: add `add_matrix="+M"`, `sub_matrix="-M"`, `mul_matrix="xM"`, `set_row="=R"`. Remove `add_rows`.
  - Update `PARAM_DEFS`: remove `add_rows`. Add `set_row = { {key="row", label="row", min=1, max=4} }`.
  - Update `DEFAULT_PARAMS`: remove `add_rows`. Add `set_row = {row=1}`.
  - Update `PALETTE_BUTTONS`: remove `{kind="op", op="add_rows", …}`. Add (after the existing ops): `{kind="op", op="add_matrix", label="+M"}`, `{kind="op", op="sub_matrix", label="-M"}`, `{kind="op", op="mul_matrix", label="xM"}`, `{kind="op", op="set_row", label="=R"}`.

  **Drawing — `draw_grid`:**
  - In Pass 2, replace the `is_ref` branch. For each ref cell, resolve `ax,ay` from the ref. Compute `dc = cx-ax` and `dr = cy-ay` (0-based offsets). Call `draw_ref_cell(anchor_tile, dc, dr, cx, cy)` instead of `draw_param_cell`.

  **New draw helper `draw_ref_cell(tile, dc, dr, cx, cy)`:**
  - For `add_matrix`, `sub_matrix`, `mul_matrix`: call `draw_matrix_value_cell(tile, dc+1, dr+1, cx, cy)` which draws the value at `tile.values[dr+1][dc+1]` (default 0) with label `"[dc+1],[dr+1]"` and dim `-`/`+` affordances in left/right thirds.
  - For `scale_row`: call `draw_scale_band(tile, dr+1, cx, cy)` — the ref cell is one of the lower bands. `dr+1` is the band index (1=top/anchor, 2–4=refs).
  - For `swap_rows`: call `draw_swap_strip(tile, dr+1, cx, cy)` — `dr+1` is strip index (1 or 2).
  - For `set_row`: `dc == 0` is the row selector — call `draw_param_cell(tile, 1, cx, cy)` (existing param cell for `PARAM_DEFS["set_row"][1]`). `dc >= 1` are value cells — call `draw_set_row_value_cell(tile, dc, cx, cy)`.
  - For other ops: fall through to existing `draw_param_cell(tile, dc, cx, cy)`.

  **Update `draw_tile` for new op visual layouts:**
  - `add_matrix` / `sub_matrix` / `mul_matrix`: draw spanning fill over `op_width(tile.op) * CELL_SIZE` wide and `op_height(tile.op) * CELL_SIZE` tall; draw op symbol in anchor cell only; draw anchor value cell via `draw_matrix_value_cell(tile, 1, 1, cx, cy)`.
  - `scale_row`: draw spanning fill over `1 × 4` cells; draw all 4 bands via `draw_scale_band(tile, 1..4, cx, cy+0..3)`.
  - `swap_rows`: draw spanning fill over `1 × 2` cells; draw both strips via `draw_swap_strip(tile, 1..2, cx, cy+0..1)`; draw `"⇅"` glyph at the border between the two cells.
  - `set_row`: draw spanning fill over `(1+tile.tile_cols) × 1` cells; draw row-selector cell (existing `draw_tile` anchor content already does this via `draw_param_cell`); draw value cells `dc=1..tile.tile_cols` via `draw_set_row_value_cell`.

  **New draw helpers:**
  - `draw_matrix_value_cell(tile, col_1based, row_1based, cx, cy)`: renders the value at `(tile.values or {})[row_1based][col_1based]` (default 0) with the orange tile colour scheme, dim `-`/`+` affordances in left/right thirds.
  - `draw_scale_band(tile, band, cx, cy)`: renders a horizontal band for `scale_row`. Selected band (`band == params.row`): bright orange background, left-aligned `"R"..band`, centred scalar `"×"..params.scalar`, left/right affordances. Unselected: dim `"R"..band` only.
  - `draw_swap_strip(tile, strip, cx, cy)`: renders one swap strip. `strip=1` → `params.row_a`; `strip=2` → `params.row_b`. Shows `"R"..row_n` centred with dim `-`/`+` affordances.
  - `draw_set_row_value_cell(tile, dc, cx, cy)`: shows value at `(tile.values or {{}})[1][dc]` (default 0) with label `"c"..dc`, dim `-`/`+` affordances.

  **Expand affordances — add to `draw_grid` after Pass 2:**
  - For every anchor cell where `tile.op` is in `{"add_matrix","sub_matrix","mul_matrix"}` and `not tile.locked`:
    - If `tile.tile_cols < 4`: draw a thin right-edge strip at `(ax + tile.tile_cols, ay)` spanning `tile.tile_rows` cells tall, labelled `"+"`.
    - If `tile.tile_rows < 4`: draw a thin bottom-edge strip at `(ax, ay + tile.tile_rows)` spanning `tile.tile_cols` cells wide, labelled `"+"`.
    - If `tile.tile_cols > 1`: draw a small `"−"` indicator inside the right edge of the rightmost anchor/ref column.
    - If `tile.tile_rows > 1`: draw a small `"−"` indicator inside the bottom edge of the bottommost row.
  - Store hit-rects for expand strips in `self._expand_rects` (cleared and rebuilt each draw call):
    ```lua
    self._expand_rects = {}
    -- for each qualifying add/sub/mul tile:
    --   push {ax=ax, ay=ay, action="grow_col"|"grow_row"|"shrink_col"|"shrink_row", x, y, w, h}
    ```
  - Also add expand affordances for `set_row` (col-only expansion): `+` strip to the right when `tile.tile_cols < 4`, `−` when `tile.tile_cols > 1`.

  **`_place_tile_at` rewrite:**
  - Compute `w = op_width(spec.op)` and `h = op_height(spec.op)`.
  - Use `grid:in_bounds_multi_2d(cx, cy, w, h)` for bounds check.
  - Check all cells `(cx..cx+w-1, cy..cy+h-1)` are free and unlocked.
  - Clear those cells.
  - Build the tile table. For `add_matrix`: `tile_rows=1, tile_cols=1, values={{0}}`. For `sub_matrix`: same. For `mul_matrix`: `tile_rows=1, tile_cols=1, values={{1}}`. For `set_row`: `tile_cols=1, values={{0}}`.
  - Set `tile.width = w` and `tile.height = h`.
  - If `h > 1` or `w > 1`: call `grid:set_multi_2d(cx, cy, tile, w, h)`. Otherwise: call `grid:set(cx, cy, tile)`.

  **`mouse_pressed` rewrite:**
  - Before the grid cell check, hit-test `self._expand_rects`. If a rect is hit: call `_resize_tile(rect.ax, rect.ay, rect.action)` and return. `_resize_tile` implementation:
    - Read anchor tile from `grid:get(ax, ay)`.
    - `grow_col`: if `tile.tile_cols < 4` — append a column of zeros (or 1s for `mul_matrix`) to `tile.values` for each row; `tile.tile_cols += 1`; `tile.width += 1`; clear old footprint; `grid:set_multi_2d(ax, ay, tile, tile.tile_cols, tile.tile_rows)`.
    - `grow_row`: symmetric for rows; `tile.tile_rows += 1`; `tile.height += 1`.
    - `shrink_col`: if `tile.tile_cols > 1` — remove last column; `tile.tile_cols -= 1`; `tile.width -= 1`; clear; re-place.
    - `shrink_row`: symmetric.
    - For `set_row` col grow/shrink: same but only cols dimension.
  - For grid cell clicks, after resolving `is_ref`:
    - Determine `dc = cx - ax` and `dr = cy - ay`.
    - **Matrix-value ops** (`add_matrix`, `sub_matrix`, `mul_matrix`): `tile.values[dr+1][dc+1] ± 1`, clamped to `[-9, 9]`.
    - **`set_row` row-selector cell** (`dc == 0`): use existing `PARAM_DEFS` path.
    - **`set_row` value cells** (`dc >= 1`): `tile.values[1][dc] ± 1`, clamped to `[-9, 9]`.
    - **`scale_row` bands**: compute `band = dr + 1`. If `band != params.row`: select (`params.row = band`). If `band == params.row`: left-third → `params.scalar -= 1`; right-third → `params.scalar += 1`, clamped to `[-9, 9]`.
    - **`swap_rows` strips**: `strip = dr + 1`; param key = `strip==1 → "row_a"` else `"row_b"`; left/right thirds dec/inc, clamped 1–4; prevent `row_a == row_b` (skip change if collision).
    - All existing param-cell handling for `scalar_mul`, `scale_row` horizontal params (removed), etc. is replaced by the above. The existing `is_ref` → `draw_param_cell` path for `scalar_mul` still works for its single ref cell.

  **`do_step` deactivation loop update:**
  - Replace `local width = (tile and tile.width) or 1` with:
    ```lua
    local width  = (tile and tile.width)  or 1
    local height = (tile and tile.height) or 1
    ```
  - Change the coverage check to: for `dr = 0..height-1`, for `dc = 0..width-1`, if `new_fp[cell_key(info.ax+dc, info.ay+dr)]` then `still_covered = true; break`.

- [x] Task 5 — `data/puzzles/06_add_rows.lua`, `data/puzzles/10_elimination.lua` — Redesign both puzzles to not use `add_rows`. Replace with solvable puzzles using the remaining ops (`transpose`, `negate`, `scalar_mul`, `scale_row`, `swap_rows`). Keep 3×3 input/target matrices for comparable difficulty. Update the comment at the top of each file to describe the new intended solution. Do not add locked tiles.

- [x] Task 6 — `tests/test_matrix_math.lua` — Add tests for the four new Matrix methods. `add_matrix`: verify element-wise addition including dimension mismatch (smaller addend leaves extra cells unchanged). `sub_matrix`: verify element-wise subtraction. `mul_matrix`: verify element-wise multiplication and that all-ones operand is identity. `set_row`: verify row replacement, out-of-range row returns unchanged copy, columns beyond operand length unchanged.
