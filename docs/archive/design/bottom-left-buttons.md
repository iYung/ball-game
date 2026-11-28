# Bottom-Left Button Layout

## Goal

Organize the bottom-left buttons of the puzzle scene the way the bottom-right ones are organized: a compact grid of equally sized buttons anchored to the corner.

Today the six instruction chips sit in one row of small 38x38 buttons partway up the bottom bar, with empty space below them. Run / Reset / Menu / Continue form a grid of 72x40 buttons, 10px from the right and bottom edges.

## Affected files

- `lua/game/scenes/matrix_scene.lua`: positions and size of the instruction chips, positions of the pusher selectors and the "INSTRUCTIONS" label
- `tests/`: coverage that pins the new chip layout

## What changes

All coordinates are in the 1280x720 logical space.

**Instruction chips** become a 3x2 grid laid out like arrow keys. They take the command buttons' metrics (72x40, 6px gap, 10px from the screen edges), so the two chip rows line up exactly with the two command button rows.

| | x=10 | x=88 | x=166 |
|---|---|---|---|
| y=624 | `.` (stop) | `^` (up) | `CLR` (clear) |
| y=670 | `<` (left) | `v` (down) | `>` (right) |

The grid ends at x=238 and y=710, clear of the timeline, which starts at x=260.

**Pusher selectors** (`A`, `B`, ...) move down to y=574 so they sit just above the grid. They start at x=10, aligned with the chips, and keep their 28x28 size and 30px step. All 8 pushers end at x=248.

**"INSTRUCTIONS" label** moves down to (10, 606), between the selectors and the grid.

```
 x=10    88      166         260
 [A][B]...                    | timeline
 INSTRUCTIONS                 |
 [  .   ][  ^   ][ CLR  ]     |     y=624
 [  <   ][  v   ][  >   ]     |     y=670
```

## What stays the same

- Chip and selector colors, the selected highlight and the disabled look. This change is layout and size only; the chips do not take the command buttons' per-button colors.
- Element ids and labels.
- All behavior: arming a chip, dragging a chip onto a slot, `CLR`, selecting a pusher, and chips and selectors being disabled while running.
- Visibility: all six chips are always shown, and a selector is shown for each pusher on the board.
- The timeline (position, size, number of visible ticks), the command buttons, the ops column, the grid and the status banner.
- Editor Test mode uses the same scene, so it gets the new layout. The editor's own bottom bar is a different scene and does not change.

## Open questions

None. Decisions made by the user:

- **Grid shape and order:** 3x2 in the arrow-key arrangement above. Rejected: a 2x3 grid, which would crowd the selectors and label or require moving the timeline.
- **Selectors and label:** move down to sit just above the grid, forming one bottom-anchored group.
- **Styling:** layout and size only.
