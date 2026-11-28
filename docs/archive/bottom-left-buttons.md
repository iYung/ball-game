## Bottom-Left Buttons Checklist

Design: `docs/archive/design/bottom-left-buttons.md`. All coordinates are logical 1280x720.

Order: A and C can run in parallel. B can be written at any time but only passes once A is done, so run it after A. Do not change existing assertions in any test or spec; if one fails, fix the code.

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — apply the new layout (layout and size only).
  - In the `BAR` table: set `PANEL_X = 10` and `PSEL_Y = BAR_Y + 34` (574). Keep `PSEL_W`, `PSEL_H` (28) and `PSEL_STEP` (30).
  - Remove `CHIP_Y`, `CHIP_W`, `CHIP_H` and `CHIP_STEP`. In `_bar_elements`, place each chip on a 3x2 grid using `CMD_BTN_W`, `CMD_BTN_H`, `CMD_BTN_GAP` and `CMD_BTN_Y`: `x = BAR.PANEL_X + col * (CMD_BTN_W + CMD_BTN_GAP)`, `y = CMD_BTN_Y + row * (CMD_BTN_H + CMD_BTN_GAP)`. Zero-based `{col, row}`: `stop` {0,0}, `up` {1,0}, `clear` {2,0}, `left` {0,1}, `down` {1,1}, `right` {2,1}. Resulting x is 10 / 88 / 166, y is 624 / 670, size 72x40.
  - Keep `CHIP_ORDER` as it is, so the element registry order, ids and labels do not change.
  - In `_draw_bar`, draw "INSTRUCTIONS" at `(BAR.PANEL_X, BAR_Y + 66)`, which is (10, 606).
  - Do not change colors, selected or disabled styling, click or drag handling, the timeline or the command buttons.

- [x] Task B — `tests/test_chip_layout.lua` (new; the headless runner picks it up automatically) — pin the new layout. Depends on A to pass. Follow the setup helpers in `tests/test_timeline_bar.lua`.
  - Build the puzzle scene for `S.puzzle("identity")` and place 8 pushers on free cells with `scene:_place_tile_at(x, y, { kind = "pusher" })`.
  - Assert the exact rect (x, y, w, h) of all six `chip:*` elements: `stop` (10,624), `up` (88,624), `clear` (166,624), `left` (10,670), `down` (88,670), `right` (166,670), each 72x40.
  - Assert `psel:A` to `psel:H` are at `x = 10 + (i-1) * 30`, `y = 574`, size 28x28.
  - Assert the two chip rows share `y` and `h` with `cmd:run` (top row) and with the second command row (`cmd:menu`), and that the bottom margin (720 - bottom edge) is 10.
  - Assert every chip and selector ends at or before `tl:scroll_left`'s x (260), and `UIRunner.check_invariants(scene:ui_elements())` returns nil.
  - Assert "INSTRUCTIONS" is drawn at (10, 606): `Stubs.drawn_text()` records strings only, so temporarily wrap `love.graphics.print` to capture x and y during one `scene:draw()`, then restore it (also on failure).

- [x] Task C — `tests/ui/28_bottom_left_buttons.lua` (new) — click every chip and every selector through real input. Passes with or without A, since it uses element ids. Today only `chip:right` and `chip:clear` are armed by a click (`chip:up`, `down`, `left` and `stop` are only dragged), and no spec clicks `psel:F`, `G` or `H`. See `docs/testing.md` and `tests/ui/09_timeline_zone.lua` for the spec format and for opening the puzzle by id with `tests/support/shipped`.
  - Spec 1: place one pusher with `P`. For each of `up`, `down`, `left`, `right`, `stop`: `click_button` the chip, `assert_button` it is `selected`, click a slot (a different tick for each), and `assert_slot` the pusher and `cmd`. Then click `chip:clear`, assert it is selected, click one of the filled slots and assert it is empty.
  - Spec 2: place 8 pushers on free cells with `P`. For each of `psel:A` to `psel:H`: click it, assert it is `selected`, click `chip:right`, click `slot:1:<n>`, and `assert_slot` with `pusher = n`.
