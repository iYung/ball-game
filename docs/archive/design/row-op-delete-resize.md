# Row-Op Delete & Resize

## Goal

Two quality-of-life fixes for the row-select op tiles (`scale_row`, `swap_rows`, `set_row`):

1. **Erase placed row-op tiles** — selecting the `[X]` erase palette tool and left-clicking a placed op tile should remove it. Currently the op-specific click handlers intercept the click and return early, so the erase path is never reached.
2. **Resize the row count** — `scale_row` is hardcoded to 4 bands and `swap_rows` to 2 strips. The user should be able to grow/shrink the tile height with the same `+`/`-` affordance strips that matrix constant ops already have.

---

## Affected files

- `game/scenes/matrix_scene.lua` — all changes live here

---

## What changes

### 1 — Fix erase for op tiles

**Root cause** (`mouse_pressed`, btn == 1 path):  
Every op-specific branch ends with `return`, so when the eraser is selected and you left-click any op tile the erase path at the bottom is never reached. Affected ops: `add_matrix`, `sub_matrix`, `mul_matrix`, `set_row`, `scale_row`, `swap_rows`, and the param cell of `scalar_mul`. Unaffected (fall through naturally): `transpose`, `negate`, anchor cell of `scalar_mul`.

**Fix**: at the top of the `btn == 1` path, right after resolving the anchor tile and before the op-specific dispatch, check `self.palette:is_eraser()`. If true, clear the tile and return.

```
-- (after anchor_tile is resolved, ~line 1113)
if anchor_tile and not anchor_tile.locked and self.palette:is_eraser() then
    self.grid:clear(cx, cy)
    return
end
```

One guard covers all affected ops at once.

### 2 — Resize row count for `scale_row` and `swap_rows`

**Current state**:
- `scale_row` draws 4 bands (hardcoded loop `for band = 1, 4 do`), no `tile_rows` stored.
- `swap_rows` draws 2 strips (hardcoded calls to `draw_swap_strip(tile, 1, …)` and `draw_swap_strip(tile, 2, …)`), no `tile_rows`.
- Neither appears in `EXPAND_OPS`; `_resize_tile` never touches them.

**Changes**:

**a. `_place_tile_at`** — when placing `scale_row` or `swap_rows`, initialise `tile_rows`:
  - `scale_row`: `tile_rows = 4` (same as before visually)
  - `swap_rows`: `tile_rows = 2` (same as before visually)
  - Set `tile.height = tile_rows` and use `grid:set_multi_2d(cx, cy, tile, 1, tile_rows)`.

**b. `draw_tile`** — replace hardcoded band/strip counts with `tile.tile_rows or N`:
  - `scale_row`: `for band = 1, (tile.tile_rows or 4) do`
  - `swap_rows`: loop from 1 to `(tile.tile_rows or 2)`, drawing one strip per row.  
    The `⇅` symbol stays at the border between strip 1 and 2.

**c. `draw_ref_cell`** — same replacement for `scale_row` and `swap_rows` (already delegates to draw helpers that use tile params, so no change needed beyond ensuring the anchor draw is consistent).

**d. `EXPAND_OPS`** — add `scale_row=true` and `swap_rows=true`. The pass-3 affordance loop will then draw `+`/`-` strips below the tile. Minimum rows: `scale_row` ≥ 1, `swap_rows` ≥ 2 (must have room for both strips); maximum: 4 for both.

**e. `_resize_tile`** — the existing `grow_row`/`shrink_row` branches already handle `tile_rows` generically. They need one guard: `swap_rows` min is 2 not 1. Add `local min_rows = (tile.op == "swap_rows") and 2 or 1`.

**f. `draw_tile` / `swap_rows` height** — update `op_height` to use `tile.tile_rows` when available. The function currently reads `OP_SIZES[op][2]`. Since op_height is called with only `op` string (no tile), change callers that have the tile to call `tile.height or op_height(tile.op)` instead.

**g. Click handler** — `scale_row` click currently uses `dr + 1` as the band index, bounded by the click coordinates. This already works generically since any band within the tile's height is a valid target. No change needed.  
`swap_rows` click uses `dr + 1` as strip index. With variable height, there are always exactly 2 logical strips mapped across potentially more than 2 visual rows — but since `swap_rows` minimum is 2 and max is 4, and each strip is one row, this still works fine.

---

## What stays the same

- Right-click to delete (already works; this is additive).
- The erase button's visual state and selection logic.
- Resize logic for matrix constant ops (`add_matrix`, `sub_matrix`, `mul_matrix`, `set_row`).
- `swap_rows` always has exactly 2 logical strips; resizing only changes the tile's visual height / how many row-band slots are shown. Since the underlying op always swaps exactly 2 rows, allowing height > 2 for swap_rows is not useful — **swap_rows resize should NOT be added**. Only `scale_row` gets row-resize.
- All puzzle `.lua` files — no changes.
- Tests — `matrix_scene` has no unit tests today; we'll add ones for the erase fix and resize in TMBP.

---

## Open questions

None — scope is clear. Proceeding to Phase 2.
