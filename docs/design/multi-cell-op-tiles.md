# Multi-Cell Op Tiles

## Goal
Op tiles physically span multiple board cells — one anchor cell for the op name/symbol, one additional cell per parameter. All param editing (increment / decrement) happens by clicking within those cells. No floating panel extends outside the tile's footprint.

---

## Affected files

| File | Why touched |
|------|-------------|
| `game/grid.lua` | Multi-cell placement: anchor cell + ref cells; clear propagates to all cells |
| `game/scenes/matrix_scene.lua` | Placement bounds check, drawing across cells, in-cell click editing, collision by anchor key |

`game/cursor.lua` and `game/matrix_math.lua` are **not touched**.

---

## What changes

### 1. Tile widths

```
transpose   → 1 cell  (no params)
negate      → 1 cell  (no params)
scalar_mul  → 2 cells (name | scalar)
scale_row   → 3 cells (name | row | scalar)
swap_rows   → 3 cells (name | row_a | row_b)
add_rows    → 4 cells (name | src | dst | scalar)
```

The anchor cell is always at the leftmost position and stores the full tile table. Each cell to the right is a **ref** cell: `{ref=true, ax=ax, ay=ay}`.

### 2. Grid changes (`grid.lua`)

- `Grid:set_multi(ax, ay, tile, width)` — places tile at `(ax,ay)`; for each `i = 1..width-1` places `{ref=true, ax=ax, ay=ay}` at `(ax+i, ay)`.
- `Grid:get(x, y)` — if the cell holds a ref, **resolves it**: returns `self.cells[ref.ay][ref.ax]`. (Callers transparently get the real tile.)
- `Grid:get_anchor(x, y)` — returns `ax, ay` for any cell of a multi-cell tile (or `x, y` if it is an anchor/nil). Used by clear and collision.
- `Grid:clear(x, y)` — resolves to anchor, then clears all cells in the tile's width range.
- `Grid:clear_all()` — iterates all cells; skips refs (anchor clear handles them) and locked cells.
- `Grid:in_bounds_multi(ax, ay, width)` — returns true if all `width` cells from `(ax,ay)` are within bounds.

### 3. Placement (`matrix_scene.lua`)

Before placing an op tile:
1. Determine `width = OP_WIDTHS[spec.op]`.
2. `grid:in_bounds_multi(cx, cy, width)` — reject if off edge.
3. Check all cells `cx` to `cx+width-1` are free and not locked.
4. Call `grid:set_multi(cx, cy, tile, width)`.

Arrow tiles and no-param ops use the existing `grid:set` path (width = 1).

### 4. Drawing param cells

The anchor cell renders the op symbol (as today).  
Each param cell renders:

```
┌─────────────────┐
│ label           │
│ ───────────── │
│  [−]  value  [+] │
└─────────────────┘
```

Left third of cell = **[−]** hit area, right third = **[+]** hit area, center shows value. No hover state needed.

The ref cell's tile param is read directly from the resolved tile.

### 5. Click editing

There is **no separate editing widget or `self.editing` state**.  
`mouse_pressed` on a param cell (a ref cell that resolves to an op tile):
- Determine which param this cell index represents (`cell_index = x - ax` → param index).
- Left third of cell → decrement that param (clamped to min).
- Right third of cell → increment that param (clamped to max).

`self.editing` and `draw_edit_widget` are removed entirely.

### 6. Collision by anchor key

`occupied_ops` currently tracks per-cell keys. With multi-cell tiles, entering **any** cell of the tile should fire the op exactly once.

Change: when processing `entered` cells, resolve each to its anchor `(ax, ay)` via `grid:get_anchor`. Use `cell_key(ax, ay)` as the key for both `occupied_ops` lookup and storage. This prevents the same tile from firing multiple times in one step (e.g., a 4-wide tile whose footprint covers two of its cells).

`_last_fp` and new_fp continue to store per-cell keys (they track physical cells, not logical tiles).

---

## What stays the same

- Arrow tiles are 1-cell; no change to their placement or drawing.
- Source and sink tiles are 1-cell; no change.
- `cursor.lua` and `matrix_math.lua` are untouched.
- `Cursor.apply_op` receives the resolved tile; works as before.
- Run / step / reset / puzzle navigation logic is unchanged.
- HUD drawing is unchanged.

---

## Open questions

None — design is fully specified.
