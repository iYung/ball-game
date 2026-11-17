# Pushers Checklist

- [x] Task 1 — `game/pusher_sim.lua` (new) — Pure-Lua sim: `DIRS`, `slot(tick,n)`, `net_push(x,y,rows,cols,w,h,pushers,slot)`, `blocked(...)` (grid edge only; pushers are non-solid), `advance(st)` (mutates `st.x/y/tick`, returns moved), and `apply_op(tile, matrix)` moved from `cursor.lua`
- [x] Task 2 — `tests/test_pushers.lua` (new) — Headless tests for slot looping, push adjacency, opposing cancel, axis clamp, blocking (grid edge), `advance`, `apply_op`
- [x] Task 3 — `game/hud.lua` — Drop the CURRENT STATE block and `current_mat` param; `HUD:draw` returns the y just below the divider; replace `loop`/`out_of_bounds` statuses with `stuck`/`timeout`
- [x] Task 4 — `game/scenes/matrix_scene.lua` — Replace the cursor with pusher sim state (`self.sim`), remove arrow tile/palette buttons, add pusher tile + palette button + letter-id allocation, timeline data (`timeline`, `timeline_n`), per-tick `do_step`, stuck/timeout statuses, timeline panel draw + click handling; delete `game/cursor.lua`
- [x] Task 5 — `data/puzzles/*.lua` — Remove locked arrows from `01_identity.lua` and `07_double_flip.lua` (and the stale cursor-path comment), drop `dir` from every `source`
- [x] Task 6 — `README.md` — Verification phase only: rewrite the cursor/arrow sections for pushers and the timeline
