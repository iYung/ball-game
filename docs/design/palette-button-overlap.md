# Palette Button Overlap Fix

## Goal

Prevent the op palette buttons and the cmd buttons (Run/Step/Reset/Menu) from overlapping in the puzzle scene.

## Affected files

- `game/scenes/matrix_scene.lua` — `_build_palette`, `_build_cmd_buttons`, `draw_palette`, `_draw_cmd_buttons`

## What changes

The op palette uses a fixed left-to-right layout starting at x=10 with gap=56 per button, and the cmd buttons are hardcoded to start at x=622. For puzzles with no `ops` restriction all 20+ palette entries are shown, reaching x≈1100 — well past the cmd buttons. There is no guard.

**Fix: make the op palette scrollable within a bounded region.**

- Define a constant `PALETTE_REGION_W` (the x-range dedicated to op tiles, ending some pixels before the cmd buttons).
- The cmd buttons stay right-aligned near HUD_X: `CMD_START_X = HUD_X - (4 * CMD_STEP + CMD_MARGIN)`.
- In `_build_palette`, always compute all button positions as before but also store a `_palette_total_buttons` count. Buttons are assigned a *slot index* (0-based) rather than an absolute x.
- Add `_palette_scroll` (integer slot offset, default 0). When drawing, only buttons whose slot falls in the visible window are shown.
- Track a `_palette_btn_scroll_left` and `_palette_btn_scroll_right` rect (small arrow buttons placed just inside the left and right edges of PALETTE_REGION_W).
- Clicks on those arrows adjust `_palette_scroll` and clamp it.
- The number of visible slots is `floor(PALETTE_REGION_W / gap)`.

No changes to the cmd buttons themselves — only their `start_x` becomes a computed constant instead of a magic number.

## What stays the same

- Button sizes (48×48, gap=56).
- The cmd button set and positions relative to HUD_X.
- Timeline, HUD, grid, and all other scene systems.
- Puzzle loading and op filtering logic.

## Open questions

None — the scrollable palette is a natural extension of the existing timeline scrolling pattern.
