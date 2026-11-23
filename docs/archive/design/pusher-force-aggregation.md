# Pusher Force Aggregation

## Goal

Replace the sequential per-pusher physics in `Sim.advance` with an aggregate-force model so that multiple pushers acting on the matrix in the same tick produce physically coherent results:

- Two pushers going the same direction → matrix moves one cell (not two).
- Two pushers going perpendicular directions → matrix moves diagonally.
- Two pushers going opposite directions on the same axis → conflict → puzzle fails.

The old model processed pushers one at a time in id order. A second pusher could contact the matrix after the first had already moved it, pushing it a second time in one tick. This caused op tiles at the intermediate position to be silently skipped.

## Affected files

- `lua/game/pusher_sim.lua` — `Sim.advance` rewritten (the only change)
- `tests/test_pusher_scene.lua` — three new tests added

## What changes

`Sim.advance` now runs in three passes instead of one loop:

**Pass 1 — classify.** Every commanded pusher is evaluated against the matrix's start-of-tick position. If its step target lands on a matrix cell and the step is otherwise valid (in-bounds, no gap, no other pusher in the way), it is a *contact* pusher. Everything else is *non-contact*.

**Pass 2 — aggregate and move.** Unique direction vectors are collected from all contact pushers (duplicates dropped). If any two unique vectors oppose on the same axis (`right` + `left`, or `up` + `down`), the result is a conflict: `blocked = true`, no move. Otherwise the unique vectors are summed into a net `(dx, dy)` and the matrix attempts one combined move to `(x+dx, y+dy)`. Validity checks (bounds, gaps, non-contact pusher overlap, contact-pusher landing collision) are the same as before. All contact pushers move to their individual target cells if the combined move succeeds.

**Pass 3 — non-contacts.** Non-contact pushers act sequentially in original id order, re-checking positions (contact pushers have already moved). They may not step into the matrix's new position; attempting to do so is `blocked`.

New cases enabled by the aggregate model:
| Situation | Old result | New result |
|---|---|---|
| Two pushers, same direction | Matrix moves 2 cells | Matrix moves 1 cell |
| Two pushers, perpendicular | Matrix moves in direction of whichever pusher ran first | Matrix moves diagonally |
| Two pushers, opposing | Matrix moves in direction of whichever ran first (second was blocked) | `blocked` → fail |

## What stays the same

- Single-pusher behavior is identical.
- `Sim.blocked`, `Sim.apply_op`, `Sim.footprint_clear`, `Sim.slot` are unchanged.
- `MatrixScene._process_footprint` is unchanged; it compares start-of-tick footprint to end-of-tick footprint as before. With the aggregate model the matrix moves at most once per tick, so there is no intermediate position to miss.
- All existing `test_pushers.lua` tests pass without modification.
- The `blocked` flag semantics are preserved: any pusher that cannot complete its commanded move sets `blocked = true`, which causes `do_step` to fail the run.
- Non-contact pushers (not touching the matrix) retain order-dependent sequential behavior.

## Open questions

None — implementation is complete and all 271 tests pass.
