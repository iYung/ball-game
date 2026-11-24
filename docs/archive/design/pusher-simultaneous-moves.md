# Pusher simultaneous moves

## Goal
Fix two bugs where valid pusher moves failed with "matrix is blocked".

## Affected files
`lua/game/pusher_sim.lua`, `docs/pusher-physics.md`, `tests/test_pusher_simultaneous.lua`

## What changes
- **Bug 2 (valid move rejected):** a pusher next to the matrix, moving away in the same tick the matrix is shoved into its cell, was judged by its start-of-tick position and reported as a collision. Now the "no pusher inside the matrix" check runs on final positions.
- **Bug 1 (pusher slides under the matrix):** the matrix push was committed before later pushers were checked. If a later check blocked the tick, the contact pushers stayed moved while the matrix snapped back, leaving a pusher inside it. A blocked push is now rolled back completely.

## What stays the same
Force combination, opposing-force conflicts, wall/gap/pusher blocking, and the "pusher blocked, others still move" behaviour when the matrix is not involved.

## Open questions
Decided without asking (unattended run): a pusher that steps toward the cell the matrix lands on stays a collision.
