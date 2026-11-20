# Timeline Zone Styling & Overflow

## Goal

Make the timeline zone visually distinct from the HUD panel above it, and support scrolling in both axes when content overflows the available space.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — `draw_timeline()`, `_timeline_layout()`, `ui_elements()`, `_tl_*` helpers
- No other files need changes

## What changes

### 1. Distinct background color

`draw_timeline()` currently draws rows on top of the same dark background as the HUD column. Add an explicit background rectangle for the timeline zone:

- **Zone rect**: `x=HUD_X, y=_tl_top, w=460, h=PALETTE_Y - _tl_top`
- **Color**: a muted teal/dark-cyan distinct from the HUD gray (`0.07,0.07,0.12`) and the grid area (`0.08,0.08,0.13`). Proposed: `(0.05, 0.10, 0.14, 1)` with a 1px top border at `(0.2, 0.4, 0.5, 1)`.

### 2. Horizontal scroll — already implemented

Horizontal slot scrolling is already in place via `timeline_scroll`, scroll buttons, and scissor clipping. No changes needed.

### 3. Vertical overflow (pusher row scroll)

The timeline row area spans `_tl_top + 20` (below the header) to `PALETTE_Y`. Each row is `TL.ROW_H = 15` px tall. With a large number of pushers and a tall HUD, rows can overflow.

**Changes needed:**

- In `_timeline_layout()`:
  - Compute `vis_rows = math.max(1, math.floor((PALETTE_Y - top - 20) / TL.ROW_H))`.
  - Track `tl_row_scroll` (new field, initialised to 0 in `load_puzzle` and `do_reset`).
  - Window the pusher list: only emit rows `tl_row_scroll + 1 .. min(tl_row_scroll + vis_rows, #pushers)`.
  - Add `scroll_up` / `scroll_down` rect entries to `L` (12×12 buttons just above/below the rows area).

- In `draw_timeline()`:
  - Apply a vertical scissor over the row area.
  - Draw scroll_up / scroll_down buttons when their respective directions are available.

- Add `_tl_scroll_up()` / `_tl_scroll_down()` helpers.

- In `ui_elements()`: register `tl:scroll_up` / `tl:scroll_down` buttons.

- In `_timeline_element_click()`: dispatch the two new ids.

- Keep `tl_row_scroll` clamped whenever `tl_row_scroll + 1 > #pushers`.

## What stays the same

- `TL.MAX_PUSHERS = 8` cap — the scroll is a safety net for small screens / tall HUDs, not a way to allow more than 8 pushers.
- `timeline_scroll` (horizontal) is untouched.
- Slot click logic, timeline length controls, and all other interactions are unchanged.
- No new files; no test-infrastructure changes needed unless the UI spec requires the new scroll buttons (see Open Questions).

## Open questions

1. Should `tl:scroll_up` / `tl:scroll_down` get UI spec coverage? Per the testing rules, every clickable element must be in `ui_elements()` and hit-test through `UI.element_at`. The vertical scroll buttons will be registered, so a minimal click test is needed.
2. Exact teal shade: `(0.05, 0.10, 0.14)` is a suggestion — open to adjustment at implementation time.
