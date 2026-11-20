## Timeline Layout Fixes Checklist

- [x] Task A — `game/scenes/matrix_scene.lua` — In `_timeline_layout()` change
  `scroll_left = { x = slot_x - 14, ... }` to `x = x0 - 14` (826 instead of 852) so
  the `<` scroll arrow sits in the left margin and no longer overlaps "TIMELINE" text.

- [x] Task B — `game/hud.lua` — Remove `STATUS_COLORS`, `STATUS_LABELS`, and the
  status-banner drawing block from `HUD:draw`; drop the `status` parameter from the
  function signature.

- [x] Task C — `game/scenes/matrix_scene.lua` — Add `STATUS_COLORS` / `STATUS_LABELS`
  tables (same values, moved from hud.lua); add `_draw_status_banner()` helper that
  draws the 40 px banner at (x=0, y=PALETTE_Y-40, w=HUD_X, h=40) in the grid panel;
  call it last in `draw()`; remove the `status` argument from the `hud:draw()` call.

- [x] Task D — `tests/ui/` or `tests/test_matrix_registry.lua` — Add/update a test
  that verifies the scroll-left button rect does not overlap the timeline header text
  rect, and that no registered UI element rect overlaps another (the existing
  check_invariants already covers element-vs-element overlaps, so verify that test
  still passes and add a spot-check for the specific scroll_left x position).
