## Timeline Clear Button Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — Add `"clear"` to `CHIP_ORDER` and `CMD_GLYPH["clear"] = "CLR"`. In `_bar_click`, when `kind == "slot"` and `btn == 1` and `self.armed_chip == "clear"`, call `Timeline.clear` instead of `Timeline.set`.
- [x] Task B — `tests/test_timeline_bar.lua` — Add a unit test: arm the CLR chip, click a filled slot, assert the slot is now nil. Also assert that arming CLR and clicking an empty slot is a no-op.
- [x] Task C — `tests/ui/09_timeline_zone.lua` — Add a UI spec step: assert `chip:clear` is registered and enabled; arm it; click a filled slot; assert the slot is empty.
