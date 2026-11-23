# Timeline Zone Styling & Overflow Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — Add `tl_row_scroll = 0` initialisation in `load_puzzle()` (near `timeline_scroll = 0`) and in `do_reset()` (near `timeline_scroll = 0`).

- [x] Task B — `lua/game/scenes/matrix_scene.lua` — In `_timeline_layout()`, compute `vis_rows` from available height (`math.floor((PALETTE_Y - top - 20) / TL.ROW_H)`), clamp `tl_row_scroll` to valid range, window the pusher list to `[tl_row_scroll+1 .. tl_row_scroll+vis_rows]`, and add `scroll_up` / `scroll_down` rect entries to `L` (small buttons placed just above/below the rows area, 12×12 each).

- [x] Task C — `lua/game/scenes/matrix_scene.lua` — In `draw_timeline()`: (1) draw the distinct teal background rect for the zone (`HUD_X, _tl_top, 460, PALETTE_Y-_tl_top`, fill `0.05,0.10,0.14,1`, then a 1px top border in `0.2,0.4,0.5,1`); (2) draw `scroll_up` / `scroll_down` buttons when their directions are available; (3) apply a vertical scissor over the row area so rows never bleed outside the zone.

- [x] Task D — `lua/game/scenes/matrix_scene.lua` — Add `_tl_scroll_up()` and `_tl_scroll_down()` helpers (mirror `_tl_scroll_left` / `_tl_scroll_right` but clamp against `tl_row_scroll` and `max_row_scroll`).

- [x] Task E — `lua/game/scenes/matrix_scene.lua` — In `ui_elements()`, register `tl:scroll_up` and `tl:scroll_down` elements (mirror the existing `tl:scroll_left` / `tl:scroll_right` entries).

- [x] Task F — `lua/game/scenes/matrix_scene.lua` — In `_timeline_element_click()`, dispatch `tl:scroll_up` → `_tl_scroll_up()` and `tl:scroll_down` → `_tl_scroll_down()`.

- [x] Task G — `tests/ui/` — Add a UI spec `tests/ui/09_timeline_zone.lua` that: places a pusher, verifies `tl:scroll_up` and `tl:scroll_down` appear in `ui_elements()`, confirms they are hit-testable via invariant checks each frame, and asserts the TIMELINE label still renders with the new background (regression guard).
