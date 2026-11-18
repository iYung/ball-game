# No Matrix Pushed Onto Pusher

## Goal

A matrix must never occupy the same cell as a pusher. Currently, when a matrix is shoved by pusher A, the simulation exempts pushers that were *already inside* the matrix footprint from blocking the move. This lets the matrix slide over those pushers, leaving them embedded inside it. The fix removes that exemption so the rule is absolute: the new matrix footprint may never overlap any other pusher, regardless of where they were before the move.

## Affected files

- `game/pusher_sim.lua` — the only file that contains the blocking logic

## What changes

In `Sim.advance`, the per-pusher blocking loop currently reads:

```lua
for _, q in ipairs(st.pushers) do
    if q ~= p and covers(nx, ny, st.rows, st.cols, q.x, q.y)
       and not covers(st.x, st.y, st.rows, st.cols, q.x, q.y) then
        ok = false; break
    end
end
```

The `and not covers(st.x, ...)` clause exempts any pusher that was already inside the old matrix footprint. Remove that clause:

```lua
for _, q in ipairs(st.pushers) do
    if q ~= p and covers(nx, ny, st.rows, st.cols, q.x, q.y) then
        ok = false; break
    end
end
```

A new test must be added to `tests/test_pushers.lua` covering the previously-allowed case: 3-wide matrix, pusher B inside the overlap region, pusher A pushing from outside — the push must now be blocked.

## What stays the same

- Single-pusher "inside pusher drags matrix" behavior is unchanged (only one pusher in the list, so the loop never fires for it).
- All existing passing tests must continue to pass.
- The `q ~= p` exclusion stays — the pushing pusher itself is still allowed to follow into the vacated cell.
- Gap blocking, edge blocking, and all other collision rules are untouched.

## Open questions

None. The reproduction is deterministic and the fix is a one-line removal.
