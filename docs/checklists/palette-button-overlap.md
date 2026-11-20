## Palette Button Overlap Checklist

- [x] Task A — `game/scenes/matrix_scene.lua` — Replace hardcoded `start_x = 622` in `_build_cmd_buttons` with a computed constant `CMD_START_X` anchored to `HUD_X` (right-align the four cmd buttons ending ~10px before HUD_X). Add `PALETTE_REGION_W` constant = `CMD_START_X - 20` (the x-range available for op tiles, excluding the left 10px margin and 10px gap before cmd buttons).

- [x] Task B — `game/scenes/matrix_scene.lua` — Refactor `_build_palette` to store slot indices instead of absolute x positions. Each button entry in `_btn_rects` gets a `.slot` field (0-based). Add `self._palette_scroll = 0` on init (and in `load_puzzle`). Add `self._palette_slot_count` = total number of visible slots (computed from `PALETTE_REGION_W`). Store total palette button count in `self._palette_total_btns`.

- [x] Task C — `game/scenes/matrix_scene.lua` — In `draw_palette`, compute each button's screen x from `10 + (slot - self._palette_scroll) * gap` and skip buttons outside the visible window. Add two small scroll arrow buttons (`_palette_scroll_left_rect` and `_palette_scroll_right_rect`) drawn at the left/right edges of the palette region when there are buttons off-screen.

- [x] Task D — `game/scenes/matrix_scene.lua` — In `mousepressed` (palette section), handle clicks on the two new scroll arrow rects to increment/decrement `_palette_scroll`, clamped to `[0, max_scroll]`. When a palette scroll adjusts, any currently-selected palette item that scrolled off-screen stays selected (selection is by kind/op, not by screen position).
