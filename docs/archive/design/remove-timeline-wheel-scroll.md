# Remove Timeline Mouse-Wheel Scroll

## Goal
Remove the mouse-wheel scroll handler from the timeline bar now that left/right arrow buttons provide the same navigation. Having two ways to scroll the same axis adds no value and can cause accidental scrolls when the user intends to scroll the page.

## Affected files
- `lua/game/scenes/matrix_scene.lua` — `wheel_moved` method and `BAR.WHEEL` constant
- `tests/ui/12_puzzle_bar_dnd.lua` — UI spec case "mouse wheel over the timeline scrolls it"

## What changes
- Delete `MatrixScene:wheel_moved` (lines 2336–2346).
- Remove `WHEEL = 3` from the `BAR` table (line 138).
- Remove the UI spec case covering wheel behaviour (lines 118–137 in `12_puzzle_bar_dnd.lua`).

## What stays the same
- `tl:scroll_left` / `tl:scroll_right` arrow buttons and their BAR.PAGE step are untouched.
- `_tl_scroll_by`, `_tl_max_scroll`, `_tl_keep_visible` — all internal scroll helpers remain.
- `SceneManager:wheel_moved` and `love.wheelmoved` wiring remain (other scenes may use them).
- Ops-column palette scroll (`wheel_moved` is not used there; it has its own arrow buttons).

## Open questions
None.
