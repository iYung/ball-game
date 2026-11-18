## No Matrix Pushed Onto Pusher Checklist

- [x] Task A — `game/pusher_sim.lua` — In `Sim.advance`, remove the `and not covers(st.x, st.y, st.rows, st.cols, q.x, q.y)` clause from the per-pusher blocking loop so the new matrix footprint may never overlap any other pusher, even one that was already inside the old footprint.

- [x] Task B — `tests/test_pushers.lua` — Add a test case under the existing "blocking" block: 3-wide matrix at (1,5), pusher B at (2,5) inside the overlap region, pusher A at (0,5) pushing right — assert the push is blocked (matrix stays at x=1, pusher A stays at x=0). Name it `"matrix cannot be shoved onto an already-inside pusher"`.
