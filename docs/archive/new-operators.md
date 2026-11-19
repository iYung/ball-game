# New Operators Checklist

## Tasks

- [x] Task 1 — `game/matrix_math.lua` — Add 8 new math functions: `scale_col`, `swap_cols`, `add_cols`, `set_col`, `rotate_90`, `flip_h`, `flip_v`, `abs`
- [x] Task 2 — `game/pusher_sim.lua` — Add `apply_op` dispatcher branches: fix `add_rows` + all 8 new ops
- [x] Task 3 — `game/scenes/matrix_scene.lua` — Wire all new ops into the UI: PARAM_DEFS, DEFAULT_PARAMS, OP_SYMBOLS, OP_SIZES, PALETTE_BUTTONS, draw helpers for column ops, mouse-click dispatch, `_place_tile_at` init
- [x] Task 4 — `tests/test_matrix_math.lua` + `tests/test_pushers.lua` — Unit tests for every new math function and apply_op round-trip tests for each new op
- [x] Task 5 — `data/puzzles/17_add_rows.lua` + `data/puzzles/18_col_ops.lua` + `data/puzzles/19_flips.lua` + `data/puzzles/20_abs_rotate.lua` — New puzzle files exercising the new ops
