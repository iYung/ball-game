## Diagonal Corner Validation Checklist

- [x] Add corner cell check to `Sim.advance` Pass 2 — `lua/game/pusher_sim.lua` — after the destination bounds/gap check, when `net_dx ~= 0 and net_dy ~= 0`, compute the two bounding-box corner cells using the general formula and set `ok = false` if either is out of bounds or a gap cell; this ensures diagonal moves cannot clip through impassable cells
- [x] Add unit tests for corner blocking — `tests/test_pushers.lua` — three sub-cases in the gap-blocking block: gap at top-right corner `(x+cols, y)` blocks the move; gap at bottom-left corner `(x, y+rows)` blocks the move; no corner gaps allows the move to succeed
- [x] Update reference doc — `docs/pusher-physics.md` — replaced the "Open question" section with "Diagonal corner cells — must be clear", documenting the implemented rule and the formula for all four diagonal directions
- [x] Write design doc — `docs/design/diagonal-corner-validation.md` — goal, affected files, formula table for all four diagonal directions, what stays the same, no open questions
