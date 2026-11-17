# Row-Op Delete & Resize Checklist

- [x] Task A — `game/scenes/matrix_scene.lua` — In `mouse_pressed`, after `anchor_tile` is resolved (~line 1113) and before the op-specific dispatch block, insert an early-return: if `anchor_tile` exists, is not locked, and `self.palette:is_eraser()` is true, call `self.grid:clear(cx, cy)` and return. This fixes erase for all op tiles.

- [x] Task B — `game/scenes/matrix_scene.lua` — In `_place_tile_at`, when placing `scale_row`, initialise `tile_rows = 4` and `tile.height = 4`, and use `grid:set_multi_2d(cx, cy, tile, 1, 4)` (replacing any existing single-cell set). This stores tile_rows on the tile so resize can read it.

- [x] Task C — `game/scenes/matrix_scene.lua` — In `draw_tile`, replace the hardcoded `for band = 1, 4 do` loop for `scale_row` with `for band = 1, (tile.tile_rows or 4) do`, and update the spanning background height to use `(tile.tile_rows or 4) * cs` instead of `h * cs` where `h` comes from `op_height`. Also fix `op_height` / `OP_SIZES` so placed tiles whose height comes from `tile.tile_rows` draw correctly — callers that have the tile should use `tile.height or op_height(tile.op)`.

- [x] Task D — `game/scenes/matrix_scene.lua` — Add `scale_row=true` to the `EXPAND_OPS` table in the pass-3 affordance loop. In `_resize_tile`, add a `min_rows` local (`local min_rows = (tile.op == "swap_rows") and 2 or 1`) and guard `shrink_row` with it instead of the hardcoded `tr > 1`.
