# Timeline Layout Fixes

## Goal

Fix two overlapping-element bugs in the puzzle scene's timeline panel:

1. **scroll-left arrow overlaps "TIMELINE" header** — the `<` button rect (x=852–864)
   covers the middle characters of "TIMELINE" (drawn at x=840), producing "TI< LINE".
2. **status banner overlaps bottom timeline rows** — the WIN/FAIL/STUCK/Running banner
   is anchored at y=620–660 in the HUD; with 8 pushers the last timeline row ends at
   y≈633, so the banner clips the bottom of the grid.

## Affected files

- `game/scenes/matrix_scene.lua` — fix scroll_left button position; own status display
- `game/hud.lua` — remove status-banner drawing

## What changes

### Bug 1 — scroll-left position (`game/scenes/matrix_scene.lua`)

In `_timeline_layout()`, the scroll_left button is currently positioned at
`slot_x - 14 = 852`, which is inside the label area (x=840–866) and overlaps the
"TIMELINE" header text.

Change `scroll_left.x` from `slot_x - 14` to `x0 - 14` (= **826**), placing the arrow
in the 20 px margin between `HUD_X=820` and `x0=840`. It no longer touches the header.

### Bug 2 — status banner position

**`game/hud.lua`**: Remove the `STATUS_COLORS` and `STATUS_LABELS` tables and the
entire status-banner drawing block from `HUD:draw`. Drop the `status` parameter from
the function (or keep it and ignore it — dropping is cleaner). Return value
(`panel_top`) is unchanged.

**`game/scenes/matrix_scene.lua`**:
- Add `STATUS_COLORS` and `STATUS_LABELS` tables (same values, moved from hud.lua).
- Add a private `_draw_status_banner()` helper that draws the 40 px banner in the
  **grid panel** at (x=0, y=`PALETTE_Y - 40`, w=`HUD_X`, h=40). No-op when
  `self.status` is nil or not in STATUS_COLORS.
- Call `self:_draw_status_banner()` as the last step in `draw()`, after
  `draw_timeline()`, so it always renders on top.
- Remove the `status` argument from the `self.hud:draw(...)` call.

## What stays the same

- Banner height (40 px), colors, and label strings are unchanged.
- `HUD:draw` return value (`panel_top`) is unchanged.
- Timeline row height, slot geometry, label area, and scissor are unchanged.
- All other drawing (grid, palette, cmd buttons, matrices, timeline slots) is unchanged.
- Status is set/cleared by the same game logic; only *where* it is drawn changes.

## Open questions

None — both root causes confirmed visually (screenshot) and by layout arithmetic.
