# Remove Timeline Wheel Scroll Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — Remove `WHEEL = 3,` from the BAR table (line 138) and delete the `MatrixScene:wheel_moved` method (lines 2336–2346 including its leading comment).
- [x] Task B — `tests/ui/12_puzzle_bar_dnd.lua` — Remove the UI spec case "mouse wheel over the timeline scrolls it" (the full spec block at lines 118–137) since the feature it covers no longer exists.
