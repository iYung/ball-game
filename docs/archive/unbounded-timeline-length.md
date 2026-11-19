# Unbounded Timeline Length Checklist

- [x] Task A — `game/scenes/matrix_scene.lua` — Raise `TL.MAX_N` from 16 to `MAX_TICKS` (500); add `self.timeline_scroll = 0` initialisation to `on_enter` (line ~170) and `do_reset` (line ~226); also reset `timeline_scroll = 0` in the run-start block (line ~290).

- [x] Task B — `game/scenes/matrix_scene.lua` — Rewrite `_timeline_layout` (line ~953) to compute a visible-slot window: derive `slot_area_x = x0 + TL.LABEL_W`, `slot_area_width = len_x - slot_area_x`, `visible_count = floor(slot_area_width / (TL.SLOT_W + TL.SLOT_GAP))`, then loop from `first = timeline_scroll + 1` to `last = min(first + visible_count - 1, timeline_n)`. Each slot rect carries a `.s` field with the actual 1-based slot index. Add `scroll_left` and `scroll_right` button rects to `L` (small `<`/`>` buttons flanking the slot area in the header row). Store `L.visible_count` and `L.slot_area_x`/`L.slot_area_w` for use by draw and click.

- [x] Task C — `game/scenes/matrix_scene.lua` — Update `draw_timeline` (line ~978): (1) draw the `<`/`>` scroll buttons from `L.scroll_left`/`L.scroll_right`, greyed when at limits; (2) set a `love.graphics.setScissor` covering only the slot area before drawing slot boxes, then clear it after; (3) fix the `current` highlight check to use `r.s` instead of loop variable `s`.

- [x] Task D — `game/scenes/matrix_scene.lua` — Update `_timeline_click` (line ~1020): (1) replace `math.min(TL.MAX_N, ...)` with `math.min(MAX_TICKS, ...)` for the `+` button; (2) handle clicks on `L.scroll_left`/`L.scroll_right` to adjust `timeline_scroll` (clamped); (3) use `r.s` for the slot index when cycling a command; (4) clamp `timeline_scroll` when `timeline_n` is decreased so it never exceeds `timeline_n - visible_count`.

- [x] Task E — `game/scenes/matrix_scene.lua` — Auto-scroll during run: in the `advance`/update path (line ~389 where `self.cur_slot` is set), after updating `cur_slot`, if `cur_slot` is outside `[timeline_scroll+1, timeline_scroll+visible_count]` adjust `timeline_scroll` to bring it into view (scroll forward); when `cur_slot == 1` (loop wrapped), reset `timeline_scroll = 0`.

- [x] Task F — `tests/test_pushers.lua` — Add tests: (1) `timeline_scroll` clamp when length is decreased; (2) visible-slot window calculation at various scroll offsets; (3) auto-scroll logic when cur_slot exceeds the visible window. These are pure-logic unit tests that do not require a running LÖVE instance.
