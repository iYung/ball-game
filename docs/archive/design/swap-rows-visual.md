# Swap Rows Visual Revamp (⇅R)

## Goal

Replace the current 3-cell horizontal `swap_rows` tile (name | r1 | r2) with a 2-tall × 1-wide vertical tile. The two stacked cells make the "two rows being exchanged" immediately legible by spatial arrangement. Each cell shows its target row number; left/right click changes which row that strip represents.

**Dependency:** Requires the 2D footprint grid changes from `docs/design/visual-matrix-add-tile.md`.

---

## Affected files

| File | Why touched |
|------|-------------|
| `game/scenes/matrix_scene.lua` | Redefine `swap_rows` footprint to 1×2, rewrite drawing and click handling |

`game/grid.lua`, `game/matrix_math.lua`, `game/cursor.lua` are **not touched**.

---

## What changes

### 1. New tile footprint

| Dimension | Old | New |
|-----------|-----|-----|
| width | 3 (name, r1, r2) | 1 |
| height | 1 | 2 |

Tile table:
```lua
{
  kind   = "op",
  op     = "swap_rows",
  params = { row_a = 1, row_b = 2 },
  locked = false,
  width  = 1,
  height = 2,
}
```

`params.row_a` and `params.row_b` are unchanged — `cursor.lua` and `matrix_math.lua` consume them exactly as before.

### 2. `OP_SIZES` (`matrix_scene.lua`)

Change `swap_rows` entry from `{3, 1}` to `{1, 2}`.

### 3. Drawing (`matrix_scene.lua`)

`draw_tile` for `swap_rows`: draw a spanning background across 1 × 2 board cells. Then draw each of the two strips:

```
┌─────────────────┐
│ [−] R1  [+]    │  ← top strip = row_a
├────── ⇅ ────────┤
│ [−] R2  [+]    │  ← bottom strip = row_b
└─────────────────┘
```

A small swap-arrow `⇅` glyph is drawn centred on the border between the two cells to indicate the direction of exchange.

**Each strip** shows the row number (e.g. `R1`) centred; dim `−`/`+` affordances in left/right thirds.

Top strip = `params.row_a`; bottom strip = `params.row_b`. Strips do not highlight (there is no "selected" state — both rows are always active).

A new draw helper `draw_swap_rows_strip(tile, strip_index, cx, cy)` renders each strip:
- `strip_index = 1` → shows `params.row_a`
- `strip_index = 2` → shows `params.row_b`

### 4. Ref cell (vertical)

`grid:set_multi_2d(cx, cy, tile, 1, 2)` places anchor at `(cx, cy)` and one vertical ref at `(cx, cy+1)`.

Strip index for the ref cell: `strip = cy - ay + 1` (always 2 for the single ref cell).

### 5. Placement (`matrix_scene.lua`)

`_place_tile_at` uses `OP_SIZES["swap_rows"] = {1,2}`:
1. `grid:in_bounds_multi_2d(cx, cy, 1, 2)`.
2. Check both cells free and unlocked.
3. `grid:set_multi_2d(cx, cy, tile, 1, 2)`.

### 6. Click editing (`matrix_scene.lua`)

`mouse_pressed` on any cell of `swap_rows`:

1. Resolve to anchor `(ax, ay)`.
2. Compute `strip = cy - ay + 1` (1 or 2).
3. Determine target param key: `strip == 1` → `"row_a"`, `strip == 2` → `"row_b"`.
4. Left third: decrement param (clamped to 1). Right third: increment param (clamped to 4).
5. Clamp so `row_a ≠ row_b`: if after increment/decrement both become equal, skip the change.

### 7. Existing puzzles

Puzzles using locked `swap_rows` tiles must update their locked tile entries to use `height=2` and remove the old horizontal param layout. The underlying `params` table is unchanged.

---

## What stays the same

- `cursor.lua` — calls `mat:swap_rows(params.row_a, params.row_b)` unchanged.
- `matrix_math.lua` — unchanged.
- All other ops — unchanged.
- Grid `clear`, `get_anchor`, `is_ref` — unchanged.

---

## Open questions

None — design is fully specified.
