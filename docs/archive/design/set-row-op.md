# Set Row Op (=R)

## Goal

Add a new op tile `set_row` (=R) that replaces one row of the travelling matrix with a user-defined constant row. The tile occupies `1 + tile_cols` horizontal board cells: a row-selector cell on the left, followed by value cells — one per column of the operand row. The player selects which matrix row to overwrite (1–4) and edits the replacement values by left/right clicking each value cell. The value strip is expandable from 1 to 4 columns.

---

## Affected files

| File | Why touched |
|------|-------------|
| `game/matrix_math.lua` | Add `Matrix:set_row(r, values)` |
| `game/cursor.lua` | Handle `set_row` op in `apply_op` |
| `game/scenes/matrix_scene.lua` | Add op to palette, drawing, placement; row-selector cell type; expand controls |

`game/grid.lua` is **not touched** (uses the existing 1D `set_multi` / `in_bounds_multi` since height is always 1).

---

## What changes

### 1. Op definition

| Op | Symbol | Footprint | Operation |
|----|--------|-----------|-----------|
| `set_row` | `=R` | 1 × (1 + cols) | Replaces row `params.row` of the current matrix with `tile.values[1][1..cols]` |

Tile table:
```lua
{
  kind      = "op",
  op        = "set_row",
  tile_cols = 1,          -- number of value cells (1..4, expandable)
  values    = { {0} },   -- [1][col] replacement values
  params    = { row = 1 },
  locked    = false,
  width     = 2,          -- 1 selector + tile_cols; kept in sync with tile_cols
  height    = 1,
}
```

### 2. Matrix math (`matrix_math.lua`)

```lua
function Matrix:set_row(r, values)
    if r < 1 or r > self.rows then return self:copy() end
    local m = self:copy()
    for c = 1, math.min(self.cols, #values) do
        m.values[r][c] = values[c]
    end
    return m
end
```

Columns in `values` beyond `self.cols` are ignored; matrix columns beyond `#values` are unchanged.

### 3. Cursor (`cursor.lua`)

```lua
elseif tile.op == "set_row" then
    local row    = (tile.params or {}).row or 1
    local values = {}
    for c = 1, tile.tile_cols or 1 do
        values[c] = (tile.values and tile.values[1] and tile.values[1][c]) or 0
    end
    return mat:set_row(row, values)
```

### 4. Scene (`matrix_scene.lua`)

**`OP_SIZES`**: add `set_row = {2, 1}` (selector + 1 value col to start; `width` grows with `tile_cols`).

**`OP_SYMBOLS`**: add `set_row = "=R"`.

**`PARAM_DEFS`**: add `set_row = { {key="row", label="row", min=1, max=4} }`. Only the selector cell uses this; value cells use `tile.values`.

**Palette**: add `{kind="op", op="set_row", label="=R"}` to `PALETTE_BUTTONS`.

**Drawing** — two cell types within a `set_row` tile:

*Selector cell* (always the leftmost cell, `dc=0`):
```
┌─────────────────┐
│ row             │
│ ─────────────  │
│ [−]  Rn  [+]   │
└─────────────────┘
```
- Label "row" at top; `Rn` = current row number centered; left/right thirds = dec/inc.
- Uses the same rendering as existing param cells (`draw_param_cell`).

*Value cells* (`dc = 1 .. tile_cols`):
```
┌─────────────────┐
│ c(dc)           │
│ ─────────────  │
│ [−]  val  [+]  │
└─────────────────┘
```
- Label shows column index; value at `tile.values[1][dc]`; left/right thirds = dec/inc.
- Rendered by a new helper `draw_set_row_value_cell(tile, dc, cx, cy)`.

Anchor cell (`dc=0`) draws the full tile background spanning `1 + tile_cols` cells (like existing anchor cells for other ops), then overlays the selector content.

**Placement**: `_place_tile_at` reads `OP_SIZES["set_row"]` → `{2,1}`, calls `grid:in_bounds_multi(cx, cy, 2)` and `grid:set_multi(cx, cy, tile, 2)`. The selector is the anchor; value cells are horizontal ref cells — same as existing multi-cell ops.

**Expand/shrink (cols only)**: a `[+]` affordance to the right of the tile adds a value column (up to 4); `[−]` affordance removes the last column (down to 1). These follow the same `_grow_col` / `_shrink_col` logic used by `add_matrix`, which calls `grid:clear` then `grid:set_multi` with the updated width.

**Click editing** in `mouse_pressed`:

- Ref cell `dc = 0` is the selector (processed via existing param-cell path: `PARAM_DEFS["set_row"]`).
- Ref cells `dc ≥ 1` are value cells: `tile.values[1][dc] ±= 1`, clamped to `[−9, 9]`. These are detected by checking `is_ref` and `tile.op == "set_row"` and `dc >= 1`.

---

## What stays the same

- All existing ops — unchanged.
- Grid — `set_row` uses the existing 1D `set_multi` / `clear` path (height always 1).
- HUD, palette selector, run / step / reset — unchanged.

---

## Open questions

None — design is fully specified.
