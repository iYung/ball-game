# Diagonal Corner Validation

## Goal

When two pushers combine to produce a diagonal matrix move, the matrix jumps from its start footprint to its destination footprint in one tick. Two "corner cells" of the bounding box lie outside both footprints — cells the matrix clips through if it had moved cardinally first. These cells were previously unchecked: a gap or wall there would not block the move. This change validates both corner cells and blocks the move if either is impassable.

## Affected files

- `lua/game/pusher_sim.lua` — corner check added to `Sim.advance` Pass 2
- `tests/test_pushers.lua` — three new sub-cases in the gap-blocking test

## What changes

For any diagonal net force `(net_dx, net_dy)` (both non-zero), two corner cells are computed from the start position `(st.x, st.y)` and matrix dimensions `(st.cols, st.rows)`:

| Direction | Corner 1 | Corner 2 |
|---|---|---|
| (+1,+1) | (x+cols, y) | (x, y+rows) |
| (-1,-1) | (x−1, y+rows−1) | (x+cols−1, y−1) |
| (+1,−1) | (x+cols, y+rows−1) | (x, y−1) |
| (−1,+1) | (x−1, y) | (x+cols−1, y+rows) |

General formula:
- Corner 1: `(x + (dx>0 ? cols : -1), y + (dy>0 ? 0 : rows-1))`
- Corner 2: `(x + (dx>0 ? 0 : cols-1), y + (dy>0 ? rows : -1))`

If either corner is out of bounds or overlaps a gap cell, `ok` is set to false → `blocked = true` → puzzle fails.

The check runs after the destination bounds/gap check (`Sim.blocked`) and only when the destination itself is valid.

## What stays the same

- Cardinal moves are unaffected — the check only fires when `net_dx ~= 0 and net_dy ~= 0`.
- `Sim.blocked` is unchanged; the corner check is inline in `Sim.advance`.
- All existing tests continue to pass.
- The destination footprint validation is unchanged.

## Open questions

None.
