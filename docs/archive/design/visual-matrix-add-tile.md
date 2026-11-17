# Visual Matrix Addition Tile (+M)

## Goal

Replace the `add_rows` op with a new `add_matrix` op that does element-wise matrix addition. The addend is defined visually: the tile occupies a 2D region of board cells, each cell showing one element of the addend matrix. The player expands the grid (up to 4×4) by clicking grow buttons at the tile's edges, and edits values by clicking the left/right third of each cell.

---

## Affected files

| File | Why touched |
|------|-------------|
| `game/grid.lua` | Extend to 2D multi-cell footprints: `set_multi_2d`, `in_bounds_multi_2d`, update `clear` to wipe full rows×cols |
| `game/matrix_math.lua` | Add `Matrix:add_matrix(addend)` for element-wise addition |
| `game/cursor.lua` | Handle `add_matrix` op in `apply_op` |
| `game/scenes/matrix_scene.lua` | Replace `add_rows` with `add_matrix` in palette, drawing, placement, expand controls, click editing |
| `data/puzzles/06_add_rows.lua` | Redesign — `add_rows` is gone |
| `data/puzzles/10_elimination.lua` | Redesign — `add_rows` is gone |

`game/hud.lua` and `game/palette.lua` are **not touched**.

---

## What changes

### 1. Op definition

| Op | Board footprint | What it does |
|----|-----------------|--------------|
| `add_matrix` | `tile_rows × tile_cols` cells | Adds the tile's stored matrix element-wise to the current matrix |

`add_rows` is **removed** from the palette, `OP_WIDTHS`, `OP_SYMBOLS`, `PARAM_DEFS`, and `DEFAULT_PARAMS`. The two add_rows puzzles are redesigned (see below).

The tile table stores:
```lua
{
  kind = "op",
  op   = "add_matrix",
  tile_rows = 1,  -- current row count (1..4)
  tile_cols = 1,  -- current col count (1..4)
  values = { {0} },  -- [row][col] numbers
  locked = false,
  width  = 1,     -- tile_cols (kept for collision logic)
  height = 1,     -- tile_rows (new)
}
```

### 2. Grid changes (`grid.lua`)

New APIs:

- `Grid:set_multi_2d(ax, ay, tile, width, height)` — places tile at `(ax,ay)`; for each `(dx, dy)` where `dx ∈ 1..width-1` or `dy ∈ 1..height-1`, places `{ref=true, ax=ax, ay=ay}` at `(ax+dx, ay+dy)`.
- `Grid:in_bounds_multi_2d(ax, ay, width, height)` — returns true if `(ax,ay)` and `(ax+width-1, ay+height-1)` are both in bounds.
- `Grid:clear(x, y)` — updated to use both `tile.width` and `tile.height` when clearing; wipes all cells in the `width × height` region.
- `Grid:clear_all()` — already skips ref cells; no change needed beyond `clear` handling 2D.

Ref cells continue to use `{ref=true, ax=ax, ay=ay}`. `get_anchor` and `is_ref` are unchanged.

### 3. Matrix math (`matrix_math.lua`)

Add:
```lua
function Matrix:add_matrix(addend)
    local m = self:copy()
    for r = 1, math.min(self.rows, addend.rows) do
        for c = 1, math.min(self.cols, addend.cols) do
            m.values[r][c] = m.values[r][c] + addend.values[r][c]
        end
    end
    return m
end
```

Mismatches are silently clamped to the overlapping region — extra cells in either matrix are ignored.

### 4. Cursor (`cursor.lua`)

Add a case in `apply_op`:
```lua
elseif tile.op == "add_matrix" then
    local rows = tile.tile_rows or 1
    local cols = tile.tile_cols or 1
    local v = tile.values or {{0}}
    local addend = Matrix.new(rows, cols, v)
    return mat:add_matrix(addend)
```

### 5. Drawing (`matrix_scene.lua`)

**Anchor cell** (`draw_tile`, `kind="op"`, `op="add_matrix"`):
- Fill the full `tile_cols × tile_rows` board-cell area with the dark op background and orange border.
- Each cell `(ax+dc, ay+dr)` is drawn by `draw_matrix_cell(tile, dc+1, dr+1, cx, cy)`:
  - Shows the value at `tile.values[dr+1][dc+1]` centred in the cell.
  - Left third = dim `−` label; right third = dim `+` label.
- The op symbol `+M` appears only in the anchor cell (top-left), overlaid at small font so it doesn't crowd the value.

**Ref cells** are drawn the same way as anchor cells for `add_matrix` — `draw_matrix_cell` is called from both paths.

**Expand affordances** (always visible on a non-locked `add_matrix` tile):
- A thin `[+]` strip rendered just outside the right edge of the tile (at `ax + tile_cols`, same row span). Width = `CELL_SIZE/3`, height = `tile_rows × CELL_SIZE`. Only shown when `tile_cols < 4`.
- A thin `[+]` strip just outside the bottom edge (at `ay + tile_rows`, same col span). Only shown when `tile_rows < 4`.
- A matching `[−]` strip on the right inside edge (shrink col). Only shown when `tile_cols > 1`.
- A matching `[−]` strip on the bottom inside edge (shrink row). Only shown when `tile_rows > 1`.

These are rendered after the tile fill so they sit on top of the board lines.

### 6. Placement (`matrix_scene.lua`)

`OP_WIDTHS` is extended to `OP_SIZES`:
```lua
local OP_SIZES = {
    -- {cols, rows}
    transpose  = {1, 1},
    negate     = {1, 1},
    scalar_mul = {2, 1},
    scale_row  = {3, 1},
    swap_rows  = {3, 1},
    add_matrix = {1, 1},  -- starts 1×1; expands in-place
}
```

For `add_matrix`, `_place_tile_at` checks `in_bounds_multi_2d(cx, cy, 1, 1)` (always passes), places a fresh `1×1` tile, and calls `grid:set_multi_2d(cx, cy, tile, 1, 1)`. Expansion happens via separate click handlers (see below).

The existing `OP_WIDTHS` table stays but is derived from `OP_SIZES` for backward-compat with collision logic.

### 7. Click editing and expansion (`matrix_scene.lua`)

**Value editing** — `mouse_pressed` on a ref or anchor cell of `add_matrix`:
- Determine `(dr, dc)` = `(cy - ay, cx - ax)` (0-based offsets from anchor).
- Left third of cell → `tile.values[dr+1][dc+1] -= 1` (clamped to −9).
- Right third of cell → `tile.values[dr+1][dc+1] += 1` (clamped to 9).

**Expand/shrink** — `mouse_pressed` on the affordance strips:
- Click the `[+]` strip to the right of the tile → `_grow_col(ax, ay)`:
  - `tile.tile_cols += 1`; initialise new column in `tile.values` to zeros; update `tile.width`.
  - Call `grid:clear(ax, ay)` (clears old footprint), then `grid:set_multi_2d(ax, ay, tile, new_w, h)`.
- Click the `[+]` strip below the tile → `_grow_row(ax, ay)`: symmetric.
- Click the `[−]` strips → `_shrink_col` / `_shrink_row`: remove last col/row, re-place.
- Affordance strips are stored in `self._expand_rects` (populated each frame in `draw`), hit-tested before the main grid cell check in `mouse_pressed`.

### 8. Collision (`matrix_scene.lua`)

Collision logic in `do_step` is unchanged structurally: `get_footprint` returns physical board cells, `get_anchor` resolves refs, and the anchor key deduplicates firing. The only needed change: `deactivation` checks `tile.width` and `tile.height` to verify the matrix has fully left the 2D footprint before removing `occupied_ops[akey]`.

### 9. Redesigned puzzles

Puzzles 06 and 10 are rewritten to use the remaining ops (`scale_row`, `swap_rows`, `scalar_mul`, `transpose`, `negate`) without locked `add_rows` tiles. New matrix values chosen so the puzzle is solvable with those ops and roughly the same difficulty.

---

## What stays the same

- `transpose`, `negate`, `scalar_mul`, `scale_row`, `swap_rows` ops — logic, drawing, param cells, all unchanged.
- Arrow tiles — unchanged.
- `Grid:get`, `Grid:is_ref`, `Grid:get_anchor` — no API change; ref structure `{ref,ax,ay}` is the same.
- `Cursor` logic (move, loop detection, sink detection) — unchanged.
- HUD, palette selector, run/step/reset/puzzle nav — unchanged.
- `matrix_math.lua` existing methods — only `add_matrix` is added.

---

## Open questions

None — design is fully specified.
