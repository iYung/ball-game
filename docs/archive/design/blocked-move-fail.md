# Blocked Move → Puzzle Fail

## Goal

Make any blocked pusher action an immediate puzzle fail. Currently, when a pusher issues a
non-idle command it cannot execute (blocked by another pusher, by a wall/edge, by a gap, or
because the matrix has nowhere to go), the pusher silently stays put and the simulation
continues. This hides bugs in the player's program and makes the system feel non-deterministic.
The fix: a blocked non-idle command is a programming error → puzzle status = "fail".

## Affected files

- `game/pusher_sim.lua` — `Sim.advance` must return a richer result that exposes whether any
  non-idle command was blocked
- `game/scenes/matrix_scene.lua` — the step loop must detect a blocked result and set
  `status = "fail"`
- `tests/test_pushers.lua` — existing "pusher collision" and "blocking" tests assert the
  silent-block behavior; they need to be updated or supplemented
- `tests/test_pusher_scene.lua` — the scene-level run loop should get a test that confirms
  a blocked move ends in fail

## What changes

### `Sim.advance` return value

Currently returns `moved` (bool). Change it to return two values: `moved, blocked`.

`blocked` is `true` when any pusher issued a non-idle command and could not execute it for
any reason:

| Blocked reason | Example |
|---|---|
| Grid edge | Pusher at x=1 issues "left" |
| Gap cell | Pusher adjacent to a gap issues a command into it |
| Another pusher | Two pushers converge on the same cell; second one is blocked |
| Matrix won't move | Pusher pushes into the matrix face but the matrix is against a wall, gap, or another pusher |

### `matrix_scene.lua` step loop

After each `Sim.advance` call, check the new `blocked` return value. If `blocked == true`,
set `scene.status = "fail"` and stop the run, the same way an out-of-bounds transform already
ends in fail.

### Order-dependent "who wins" behavior

The existing sequential order (pushers act in array order) is **kept as-is** for the case
where the first pusher moves away before the second arrives — that is not a collision and not a
fail. A fail only fires when a pusher's command is actually rejected.

## What stays the same

- Pushers continue to act in array order (insertion/ID order) within a tick
- Idle commands (`nil` or `"idle"`) are never a fail — a pusher that does nothing is fine
- Win/stuck/no_pusher detection is unchanged
- `Sim.footprint_clear` is unchanged
- All existing passing tests that do not rely on silent-block behavior remain green

## Open questions

1. **Grid edge**: Should a pusher walking into the grid boundary also fail? The user said
   "if anything is ever blocked" which suggests yes, but hitting a wall is different from a
   logical collision — some puzzle designs may rely on a pusher naturally stopping at the edge.
   **Decision needed before implementation.**

2. **Status label**: Should the fail reason be reported as `"fail"` (same as a wrong-answer
   matrix) or a distinct `"blocked"` status so the UI can show a different message
   ("Collision!" vs "Wrong answer")? A distinct status would let the HUD give clearer feedback
   but requires a new string constant and HUD case.
