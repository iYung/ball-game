# Timeline Clear Button

## Goal

Add a "CLR" instruction chip to the pusher timeline bar so players can clear a timeline slot by arming the chip and clicking the slot — consistent with how the existing direction chips work, and without requiring right-click.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — add `"clear"` to `CHIP_ORDER`, handle it in `_bar_click`, register/draw it
- `tests/test_timeline_bar.lua` — unit test: arming CLR then clicking a slot clears it
- `tests/ui/09_timeline_zone.lua` — UI spec: CLR chip is registered, enabled, selectable, and clears a filled slot on click

## What changes

- `CHIP_ORDER` gains a sixth entry `"clear"`. `CMD_GLYPH["clear"]` = `"CLR"` (display label).
- `_bar_click` for `kind == "slot"`, `btn == 1`: if `self.armed_chip == "clear"` call `Timeline.clear` instead of `Timeline.set`.
- The chip button is drawn in the bar like the existing chips. Because it doesn't write a command it needs no entry in `CMD_GLYPH`'s direction glyphs; it already fits because the display label is used only for the chip button itself, not slot labels.
- No `Timeline.set` call is made when the CLR chip is armed — the slot is cleared.

## What stays the same

- Right-click on a slot still clears it (existing shortcut, unaffected).
- All existing chips (up, down, left, right, stop) are unchanged.
- `CMD_GLYPH` entries for the five direction chips are unchanged; `slot_label` only uses `CMD_GLYPH[c.cmd]` for filled slots (which never have `cmd == "clear"`).
- Timeline model (`timeline.lua`) is not touched.

## Open questions

None.
