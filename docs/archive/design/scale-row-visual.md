# Scale Row Visual Revamp (×Rn)

## Goal

Replace the current 3-cell horizontal `scale_row` tile (name | row | scalar) with a 4-tall × 1-wide vertical band tile. Each band corresponds to one matrix row (R1–R4). The player clicks a band to select the target row (highlighted) and left/right clicks within the selected band to change the scalar. This makes the row being operated on immediately legible by position rather than an abstract number.

**Dependency:** Requires the 2D footprint grid changes from `docs/design/visual-matrix-add-tile.md` (the `set_multi_2d`, `in_bounds_multi_2d`, 2D `clear`).

---

## Affected files

| File | Why touched |
|------|-------------|
| `game/scenes/matrix_scene.lua` | Redefine `scale_row` footprint to 1×4, rewrite drawing, rewrite click handling |

`game/grid.lua`, `game/matrix_math.lua`, `game/cursor.lua` are **not touched** — the underlying op is unchanged.

---

## What changes

### 1. New tile footprint

| Dimension | Old | New |
|-----------|-----|-----|
| width | 3 (name, row, scalar) | 1 |
| height | 1 | 4 |

Tile table:
```lua
{
  kind   = "op",
  op     = "scale_row",
  params = { row = 1, scalar = 2 },
  locked = false,
  width  = 1,
  height = 4,
}
```

`params.row` and `params.scalar` are unchanged — `cursor.lua` and `matrix_math.lua` consume them exactly as before.

### 2. `OP_SIZES` (`matrix_scene.lua`)

Change `scale_row` entry from `{3, 1}` to `{1, 4}`.

### 3. Drawing (`matrix_scene.lua`)

`draw_tile` for `scale_row`: draw a tall spanning background covering 1 × 4 board cells. Then for each band `r = 1..4`:

```
┌─────────────────┐
│ R1              │  ← dim if not selected
├─────────────────┤
│ R2  ×k          │  ← highlighted + scalar if selected (row=2 here)
├─────────────────┤
│ R3              │  ← dim
├─────────────────┤
│ R4              │  ← dim
└─────────────────┘
```

Each band occupies one board cell vertically.

**Unselected band**: dim orange `Rn` label centred.

**Selected band** (`r == params.row`): bright orange background highlight, `Rn` label on the left, scalar value centred-right (`×k`), dim `−`/`+` affordances in left and right thirds of the cell.

The op symbol `×Rn` is not drawn separately — the band layout makes the op self-evident.

Ref cells for `scale_row` are the cells below the anchor (vertical refs: `dy = 1, 2, 3`). They are drawn via `draw_scale_row_band(tile, band_index, cx, cy)` which is called from both the anchor and ref-cell draw paths.

### 4. Ref cells (vertical)

`grid:set_multi_2d(cx, cy, tile, 1, 4)` places the anchor at `(cx, cy)` and three vertical refs at `(cx, cy+1)`, `(cx, cy+2)`, `(cx, cy+3)`.

`is_ref` / `get_anchor` already work for vertical refs since refs only store `{ref=true, ax=ax, ay=ay}` — no changes needed.

Band index for a ref cell: `band = cy - ay + 1` (1-based from anchor).

### 5. Placement (`matrix_scene.lua`)

`_place_tile_at` uses `OP_SIZES["scale_row"] = {1,4}`:
1. `grid:in_bounds_multi_2d(cx, cy, 1, 4)` — reject if off edge.
2. Check all four cells `(cx, cy)..(cx, cy+3)` are free and unlocked.
3. Call `grid:set_multi_2d(cx, cy, tile, 1, 4)`.

### 6. Click editing (`matrix_scene.lua`)

`mouse_pressed` on any cell of a `scale_row` tile (anchor or vertical ref):

1. Resolve to anchor `(ax, ay)` via `get_anchor`.
2. Compute `band = cy - ay + 1` (1-based).
3. If `rel_x < CELL_SIZE/3`: the click is a **band select** — set `tile.params.row = band`. No scalar change.
4. If `rel_x >= CELL_SIZE/3` and band is the **selected band** (`band == params.row`):
   - Left third (already handled above) = select.
   - Middle third = no-op.
   - Right third (`rel_x >= CELL_SIZE * 2 / 3`) = `params.scalar += 1`, clamped to `[−9, 9]`.
   - Left third = also scalar decrement for the selected band. Since left-third already handles band selection, disambiguate: left-third on the already-selected band = scalar decrement. Left-third on a non-selected band = select that band (no scalar change).

Revised disambiguation:
- Band is **not selected**: clicking anywhere selects it (`params.row = band`).
- Band is **selected**: left-third = `params.scalar -= 1`; right-third = `params.scalar += 1`; middle = no-op.

This requires checking `band == params.row` before determining left/right intent.

### 7. Existing puzzles

Puzzles using locked `scale_row` tiles (e.g. puzzle 05 `scale.lua`) must update their locked tile entries to use `height=4` and remove the old horizontal layout. Locked band tiles show a lock icon on the anchor cell.

---

## What stays the same

- `cursor.lua` — `apply_op` calls `mat:scale_row(params.row, params.scalar)` unchanged.
- `matrix_math.lua` — unchanged.
- All other ops — unchanged.
- Grid `clear`, `get_anchor`, `is_ref` — unchanged (vertical refs use same structure as horizontal).

---

## Open questions

None — design is fully specified.
