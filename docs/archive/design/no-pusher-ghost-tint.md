# Design: Remove ghost-matrix tint when no pusher is placed

## Goal

Suppress the faded (0.45 alpha) preview of the input matrix that currently
renders over the source cell as soon as a puzzle loads, before the player has
placed any pusher.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — `draw_travelling_matrix()`

## What changes

`draw_travelling_matrix()` has two branches:

1. **Running/animating** (`self.current_matrix ~= nil`): draws the matrix in
   motion at full alpha. Unchanged.
2. **Idle preview** (`self.current_matrix == nil`, `self.sim == nil`,
   `self.input_matrix` present): renders each matrix cell at 0.45 alpha over
   the source tile as a ghost hint. This is the "tint".

The fix: add a guard so the idle preview only renders when at least one pusher
has been placed on the grid:

```lua
if self.sim == nil and self.input_matrix and #self:_pusher_list() > 0 then
```

Before the fix the preview appeared immediately on puzzle load (zero pushers).
After the fix it appears only once the player places their first pusher, giving
them a visual cue of what will move through the grid.

## What stays the same

- The idle preview rendering code itself (colors, alpha, font, layout) is
  unchanged.
- The running/animating branch is untouched.
- Status banner logic (`no_pusher`, etc.) is untouched.
- All other drawing helpers are untouched.

## Open questions

None.
