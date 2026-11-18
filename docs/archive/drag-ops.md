## Drag Ops Checklist

- [x] Task A — `game/palette.lua` — Add `is_drag()` helper method that returns `true` when `self._selected` has `kind == "drag"`, mirroring the existing `is_eraser()` pattern.

- [x] Task B — `game/scenes/matrix_scene.lua` — Add `{kind="op", op=nil, label="Mv", drag=true}` entry to `PALETTE_BUTTONS` (just before the `{erase=true}` entry). Update `_build_palette` to handle the new button: clicking it calls `self.palette:select({kind="drag"})`. Update `draw_palette` to highlight it correctly when `self.palette:is_drag()` returns true.

- [x] Task C — `game/scenes/matrix_scene.lua` — Add drag state fields (`self._drag_tile`, `self._drag_origin`, `self._drag_ghost`) initialised to `nil` in `on_enter` and cleared in `do_reset`. Add a `_clear_drag()` helper that nils all three and re-places the held tile at its origin (cancel path).

- [x] Task D — `game/scenes/matrix_scene.lua` — Extend `mouse_pressed` to handle drag pickup: when `btn == 1`, the palette is in drag mode (`self.palette:is_drag()`), the click is inside the grid panel, and the target cell holds a non-locked, non-gap tile — resolve its anchor, copy the tile reference into `self._drag_tile`, store anchor coords in `self._drag_origin`, call `self.grid:clear(anchor_x, anchor_y)`. Right-click (`btn == 2`) while dragging calls `_clear_drag()`.

- [x] Task E — `game/scenes/matrix_scene.lua` — Add `mouse_moved(mx, my)` method. When `self._drag_tile` is non-nil and the cursor is inside the grid panel, compute the cell under the cursor and store it in `self._drag_ghost` (set to `nil` when off-grid). The scene needs to receive this callback: wire it up in `main.lua` / `lua/core/scene_manager.lua` by forwarding `love.mousemoved` to the active scene's `mouse_moved` if it exists.

- [x] Task F — `game/scenes/matrix_scene.lua` — Add `mouse_released(mx, my, btn)` method. When `btn == 1` and `self._drag_tile` is non-nil: if `self._drag_ghost` is set and the target fits (bounds check via `grid:in_bounds_multi_2d` using tile `width`/`height`, and all cells in the footprint are empty or only ref cells owned by the tile being moved), place the tile at `self._drag_ghost` using `grid:set_multi_2d` (or `grid:set` for 1×1) and clear drag state; otherwise call `_clear_drag()`. Wire `love.mousereleased` → active scene in `main.lua` / `scene_manager.lua`.

- [x] Task G — `game/scenes/matrix_scene.lua` — Draw ghost in `draw_grid` after the normal tile passes: when `self._drag_tile` is non-nil and `self._drag_ghost` is set, compute validity the same way as Task F, then draw the spanning background at the ghost cell at ~0.5 alpha, tinted green (`0.2, 0.8, 0.2`) if valid or red (`0.8, 0.2, 0.2`) if invalid, plus the op symbol label so the player can see what they're placing.
