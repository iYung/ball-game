# NxM Matrix + Gap Cells Checklist

- [x] Task A — `game/pusher_sim.lua` — Add `gaps` support to `Sim.blocked` and `Sim.advance`: accept `gaps` (a `{[y]={[x]=true}}` lookup) in the state table; return blocked if any cell of the proposed new matrix position overlaps a gap; prevent pushers from stepping onto gap cells.

- [x] Task B — `game/scenes/matrix_scene.lua` (load + sim state) — In `load_puzzle`, build a `self.gaps` lookup from `p.gaps` (default empty) and place `{kind="gap", locked=true}` tiles on the grid for each gap. In `start_run`, pass `gaps=self.gaps` in the sim state table so `Sim.advance` receives it.

- [x] Task C — `game/scenes/matrix_scene.lua` (dynamic op sizing) — Make `scale_row` tile height dynamic: store `matrix_rows` on placed tiles; replace hardcoded `{1,4}` in `OP_SIZES` with a per-tile lookup in `op_height`; change `draw_tile`'s `for band = 1, 4` to use `tile.matrix_rows`. Clamp `PARAM_DEFS` row `max` values (`scale_row.row`, `swap_rows.row_a`, `swap_rows.row_b`) to `self.puzzle.input.rows` at load time by building a per-puzzle `_param_maxes` table.

- [x] Task D — `game/scenes/matrix_scene.lua` (gap rendering) — In `draw_grid` pass 1, render gap cells with a dark fill (distinct from normal checkerboard). In pass 2, skip drawing tile content for gap cells (they have no interactive content). Gap cells should look clearly impassable (e.g. dark gray with an "×").

- [x] Task E — `data/puzzles/11_rotate_gap.lua` — New puzzle "Tight Fit": 2×3 input matrix, `transpose` op, 3×2 target, gap corridor at x=5–6 blocking rows y=1–3 and y=7–10 (leaving a 3-row opening at y=4–6 for the transposed 3×2 footprint to pass). Register it in `game/puzzle_loader.lua`.
