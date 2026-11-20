## Idle Matrix Preview Checklist

- [ ] Task A — `lua/game/scenes/matrix_scene.lua` — In `draw_travelling_matrix`, before the early-return on `not mat`, add a branch: when `sim == nil` (idle/pre-run state), draw `input_matrix` at the source cell position (`cell_top_left(self.puzzle.source.x, self.puzzle.source.y)`) with alpha 0.45 on the fill and border colors, then return. This should use the same per-cell loop as the existing running path but with dimmed colors to signal the preview state. No animation offsets; position is fixed at source.

- [ ] Task B — `tests/ui/matrix_scene_spec.lua` — Add a UI spec that loads puzzle 1, verifies (via `scene:ui_matrix()`) that the matrix values are visible in the idle state before any pusher is placed, and again after `do_reset()`.
