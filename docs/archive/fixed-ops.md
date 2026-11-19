# Fixed Ops Checklist

## Tasks

- [x] Task 1 — `game/scenes/matrix_scene.lua` — Extend locked-op loading: replace `grid:set` with `grid:set_multi_2d` for multi-cell ops, pass `width`/`height`/`tile_rows`/`tile_cols`/`values` from the puzzle's `locked` entries
- [x] Task 2 — `game/scenes/matrix_scene.lua` — Player-placed fixed ops: read `puzzle.fixed_ops` in `_build_palette`, pass `fixed` flag through palette selection → `_place_tile_at`; set `fixed=true` on placed tiles; palette renders a separator + fixed-variant buttons
- [x] Task 3 — `game/scenes/matrix_scene.lua` — Visual style + interaction guards for fixed tiles: param cells show `[=]` instead of -/+; param values rendered dimmed; `mouse_pressed` skips param-editing when `tile.fixed`; `_resize_tile` and expand/shrink affordances skip fixed tiles
- [x] Task 4 — `data/puzzles/21_fixed_player.lua` + `data/puzzles/22_fixed_puzzle.lua` — New puzzles: one using `fixed_ops` (player-placed fixed), one using a puzzle-placed locked op via the `locked` array
- [x] Task 5 — `tests/test_pusher_scene.lua` (or a new test file) — Tests: verify fixed player-placed tile can be placed/moved but param edit is a no-op; verify puzzle-placed locked multi-cell op loads correctly and fires in simulation
