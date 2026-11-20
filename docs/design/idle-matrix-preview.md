## Goal

Remove the dark, empty-grid experience the player sees when they first open a puzzle and before any pusher has been placed. Right now `draw_travelling_matrix` draws nothing until `current_matrix` is set (which only happens on Run), so the entire grid area is just near-black checkerboard cells — visually dead.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — `draw_travelling_matrix` and `draw_grid` are the only draw sites that need changing.

## What changes

**`draw_travelling_matrix`** currently bails out when `current_matrix` is nil. In the idle/pre-run state (`sim == nil` and `current_matrix == nil`), draw the `input_matrix` fixed at the source cell (`puzzle.source.x/y`) with no animation — `anim_t = 1`, position locked to source top-left. This gives the board something bright (the yellow matrix cells) right from puzzle load, matching what the player will see the moment Run begins.

The matrix should appear slightly dimmed in the idle state (alpha ≈ 0.45) to visually signal that it has not started moving yet, while still eliminating the near-black empty board.

## What stays the same

- Once `start_run()` is called, `current_matrix` is set and the existing animated path takes over — no changes to the running/win/fail paths.
- `do_reset()` sets `current_matrix = nil`, returning to the preview state automatically.
- All simulation logic, timing, and status banner logic are untouched.
- The `anim_from_x/to_x` and `anim_t` fields are only used when `current_matrix` is set, so they don't need to change.

## Open questions

None — the fix is a small, isolated change to the draw path only.
