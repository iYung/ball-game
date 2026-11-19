# New Operators

## Goal

Extend the op-tile palette with eight additional matrix operations:

1. **Fix `add_rows`** — it is fully defined in `matrix_math.lua` and used by puzzle 14, but the `apply_op` dispatcher in `pusher_sim.lua` has no branch for it, so the tile currently silently no-ops.
2. **Column ops** — `scale_col`, `swap_cols`, `add_cols`, `set_col` as column-symmetric counterparts to the existing row ops.
3. **Simple whole-matrix ops** — `rotate_90`, `flip_h`, `flip_v`, `abs`.

## Affected files

| File | Change |
|------|--------|
| `game/matrix_math.lua` | New functions: `scale_col`, `swap_cols`, `add_cols`, `set_col`, `rotate_90`, `flip_h`, `flip_v`, `abs` |
| `game/pusher_sim.lua` | New `apply_op` branches for `add_rows` (fix) + all 8 new ops |
| `game/scenes/matrix_scene.lua` | `PARAM_DEFS`, `DEFAULT_PARAMS`, `OP_SYMBOLS`, `OP_SIZES`, `PALETTE_BUTTONS`, draw helpers, mouse-click dispatch |
| `tests/test_matrix_math.lua` | Unit tests for every new math function |
| `tests/test_pushers.lua` | `apply_op` round-trip tests for each new op |
| `data/puzzles/` | Up to 4 new puzzles exercising the new ops |

## What changes

### 1. `add_rows` fix (pusher_sim.lua only)

Add one `elseif op == "add_rows"` branch to `Sim.apply_op`:

```lua
elseif op == "add_rows" then
    local src = math.max(1, math.min(n, p.src or 1))
    local dst = math.max(1, math.min(n, p.dst or 2))
    if src == dst then return matrix end
    return matrix:add_rows(src, dst, p.scalar or 1)
```

`add_rows` already has entries in `param_popup.lua`, `PARAM_DEFS` does not yet list it, so it also needs entries in `PARAM_DEFS`, `DEFAULT_PARAMS`, `OP_SYMBOLS`, `OP_SIZES`, and `PALETTE_BUTTONS` in `matrix_scene.lua`.

Tile layout: `{4, 1}` — anchor cell + 3 param cells (src row, dst row, scalar). Mouse-click handling follows the generic param-cell path that `scalar_mul` uses.

### 2. Column operations (new math)

All four functions are added to `matrix_math.lua`:

| Function | Semantics |
|----------|-----------|
| `scale_col(c, s)` | `M[r][c] *= s` for all r |
| `swap_cols(a, b)` | Exchange columns a and b |
| `add_cols(src, dst, s)` | `M[r][dst] += s * M[r][src]` for all r |
| `set_col(c, values)` | `M[r][c] = values[r]` for all r |

#### `scale_col` tile

Symmetric to `scale_row`: spans `matrix.cols` cells wide × 1 tall. Default `tile_cols = 4`. Each horizontal band represents one column; click to select, then adjust scalar with left/right thirds.

New draw helper: `draw_scale_col_band(tile, band, cx, cy)` — same layout as `draw_scale_band` but labels "C1"/"C2"/… and uses `dc` offset instead of `dr`.

`draw_ref_cell` gains a `scale_col` branch: `dc` offset determines which band to draw.

#### `swap_cols` tile

Symmetric to `swap_rows`: 2 wide × 1 tall. Two side-by-side strips, each holding a column index. New draw helper `draw_swap_col_strip(tile, strip, cx, cy)`.

`draw_ref_cell` gains a `swap_cols` branch dispatching on `dc == 1` for the second strip.

#### `add_cols` tile

Same shape as `add_rows`: `{4, 1}` — anchor + 3 param cells (src col, dst col, scalar). Reuses the generic param-cell draw path.

#### `set_col` tile

Symmetric to `set_row`: `{1, ?}` — anchor cell (top, holds col selector) + value cells going **down** (one per matrix row). Default height = `input.rows + 1`. Unlike `set_row` which grows right, `set_col` grows down.

`draw_ref_cell` for `set_col`: `dr == 0` → col selector; `dr >= 1` → value cell for row `dr`.

Mouse-click handling: col selector on `dr == 0`, value cell on `dr >= 1`.

### 3. Simple whole-matrix ops (new math + minimal UI)

Each is a 1×1 tile with no parameters and no ref cells.

| Op | Semantics |
|----|-----------|
| `rotate_90` | 90° clockwise; n×m → m×n, `new[j][n−i+1] = old[i][j]` |
| `flip_h` | Mirror left-right (reverse column order); `new[r][c] = old[r][cols−c+1]` |
| `flip_v` | Mirror up-down (reverse row order); `new[r][c] = old[rows−r+1][c]` |
| `abs` | Element-wise absolute value |

`rotate_90`, `flip_h`, and `flip_v` can change the matrix dimensions (rotate_90 swaps them; flips preserve them). The existing footprint-clear check in `_process_footprint` already handles dimension changes (it re-checks every time), so no new mechanics are needed.

### 4. New puzzles

Up to 4 new puzzle files in `data/puzzles/` (numbered 17–20) that use subsets of the new ops. Exact puzzle designs are deferred to the checklist phase but each should be playable with 1–2 pushers and 1–3 op tiles.

## What stays the same

- Puzzle-select screen, win/lose logic, pusher simulation, timeline, drag-move, and all existing op tiles are unchanged.
- The `add_rows` math in `matrix_math.lua` is correct and unchanged; only the dispatcher needs a new branch.
- Value clamping (−9 to 9) and expand/shrink affordances apply to `scale_col`, `swap_cols`, `add_cols`, `set_col` with the same rules as their row equivalents.
- `rotate_90`, `flip_h`, `flip_v`, `abs` have no editable parameters.

## Open questions

None — scope confirmed by user.
