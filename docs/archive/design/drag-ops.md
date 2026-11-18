# Drag Op Tiles

## Goal

Let the player move already-placed operation tiles to new grid cells without erasing and re-placing them, preserving all configured parameters and values.

## Affected files

- `game/scenes/matrix_scene.lua` — palette buttons, mouse input, draw loop
- `game/palette.lua` — add `drag` kind to selected state

## What changes

### Palette
A new **[Mv]** button is added to `PALETTE_BUTTONS`, between the separator and the erase button (or immediately before `[X]`). Selecting it sets the palette to `{kind="drag"}`.

### Drag state on `MatrixScene`
Three new fields track in-progress drags:

```
self._drag_tile   -- the tile table being dragged (nil when not dragging)
self._drag_origin -- {x, y} cell the tile was lifted from
self._drag_ghost  -- {cx, cy} current cell under cursor (nil when cursor is off-grid)
```

### `mouse_pressed` (button 1)
When the palette is in drag mode and the user presses on a non-locked tile in the grid:
1. Read the anchor position via `grid:get_anchor`.
2. Copy the tile reference into `self._drag_tile`.
3. Store `self._drag_origin`.
4. Clear the original footprint from the grid (`grid:clear`).

### `mouse_moved`
New callback (LÖVE calls `love.mousemoved` → forwarded via `Scene`). While `self._drag_tile` is non-nil:
- Compute the cell under the cursor.
- Update `self._drag_ghost`.

### `mouse_released` (button 1)
While dragging:
- If `self._drag_ghost` is on a valid, unoccupied (non-locked) cell that fits the tile's full footprint, place the tile there via `grid:set_multi_2d` (or `grid:set` for 1×1).
- Otherwise, place it back at `self._drag_origin` (cancel drag).
- Clear `self._drag_tile`, `self._drag_origin`, `self._drag_ghost`.

Right-click during a drag cancels (places back at origin).

### Draw ghost
In `draw_grid`, after the normal tile passes, when `self._drag_tile` is non-nil:
- Draw the tile's spanning background at the ghost cell, at reduced alpha (~0.5), to preview placement.
- Tint green if the target is valid (fits, all cells empty/unlocked), red if invalid.

### Interaction with running simulation
Drag is blocked while `self.running` is true (same guard as resize affordances).

## What stays the same

- All existing palette tools (place, erase) work exactly as before when the palette is not in drag mode.
- Op parameters and values on the dragged tile are preserved — the same tile table is re-inserted at the new location.
- Locked tiles (source, sink, gaps, puzzle-defined locked ops) cannot be picked up.
- Resize affordances (+/- strips) are unaffected.
- Timeline and HUD are unaffected.

## Open questions

None — approach confirmed with user.
