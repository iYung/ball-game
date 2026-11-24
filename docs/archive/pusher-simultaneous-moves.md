## Pusher simultaneous moves Checklist

- [x] Task A — `lua/game/pusher_sim.lua` — snapshot positions; roll back when a committed push is later blocked
- [x] Task B — `lua/game/pusher_sim.lua` — replace pre-move pusher overlap check with a final-position check
- [x] Task C — `tests/test_pusher_simultaneous.lua` — regression tests for both bugs
- [x] Task D — `docs/pusher-physics.md` — document both rules
