## Goal
Remove the dark screen tint shown in the puzzle scene before any pusher is placed.

## Affected files
- `lua/game/scenes/matrix_scene.lua` — end of `MatrixScene:draw()`

## What changes
`main.lua` draws the scene into a canvas, then composites it with `love.graphics.draw(canvas)`, which multiplies by the current draw color. With no pusher, `draw_timeline` returns early right after `setColor(0.45, 0.45, 0.6, 1)` (the "Place a pusher [P]" hint), and nothing resets the color afterward, so the whole screen is tinted. `MatrixScene:draw()` now ends with `setColor(1, 1, 1, 1)`.

## What stays the same
- The idle input-matrix preview over the source cell is unchanged (a first attempt hid it; that was the wrong target).
- All scene layout and colors are unchanged; only the final draw color is reset.

## Open questions
None.
