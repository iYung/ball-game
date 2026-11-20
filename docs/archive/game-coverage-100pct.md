## game-coverage-100pct Checklist

- [x] Task A — `tests/test_param_popup.lua` (new unit test) — open/close, all FIELD_DEFS op types via open(), key_pressed escape/return/tab/backspace, text_input, _try_confirm happy path and error paths (non-numeric, float-for-int), draw() with 0 fields, draw() with _error set. Brings param_popup.lua 0%→100%.

- [x] Task B — `tests/test_game_scene.lua` (new unit test) — runner.setup with GameScene.new() as factory; runner.tick 2 frames; Player.new + centre() + draw(); stub love.keyboard.isDown to return true for each direction key and call player:update(1/60) four times. Brings game_scene.lua 50%→100% and player.lua 50%→100%.

- [x] Task C — `tests/ui/06_cutscene.lua` (new UI spec, two specs) — Spec 1: given={solved={1,2,3,4,5}}, press return→level select, press right→world 2 (unlocked, unseen)→CutsceneScene loads; assert_text for first beat speaker; press return three times to advance through all beats back to level select. Spec 2: same setup, press escape after entering cutscene→returns to level select. Brings cutscene_scene.lua 0%→100%.

- [x] Task D — extend `tests/ui/02_level_select_keyboard.lua` (add a new spec entry to the returned list, do NOT change existing specs or assertions) — given={solved="all"}; press return→level select; press right twice to reach world 5; press left once; assert world 4 puzzles are shown; press "u" key to fire Progress.unlock_world. Brings level_select_scene.lua 97%→100%.

- [x] Task E — `tests/test_pushers.lua` additions + dead-code deletion — add apply_op cases for sub_matrix, mul_matrix, set_row (n=2), add_rows with src==dst (returns matrix unchanged), add_cols with src==dst; delete the `sign` function from lua/game/pusher_sim.lua (dead code, never called by anything). Brings pusher_sim.lua 83%→100%.

- [x] Task F — `tests/test_pusher_scene.lua` additions — add test case: build a PusherSim, call sim:do_step() 501 times so sim.tick exceeds MAX_TICKS (500), assert sim.status == "timeout". Covers the timeout branch in pusher_sim and matrix_scene.

- [x] Task G — `tests/test_puzzle_loader.lua` (new unit test) — PuzzleLoader.load(0) errors; PuzzleLoader.load(999) errors; PuzzleLoader.world(0) errors; PuzzleLoader.world(999) errors; temporarily stub love.filesystem.load to return nil and assert the "could not load" error path fires. Brings puzzle_loader.lua 62%→100%.

- [x] Task H — `tests/test_solution_recap.lua` additions — build a SolutionRecapScene with a small _run_frames list; tick past the last frame to set _holding=true; tick further until _end_hold<=0 so _frame_idx resets to 1 (loop-back path). Brings solution_recap_scene.lua 89%→100%.

- [x] Task I — `tests/test_basics.lua` or `tests/test_scene.lua` additions — place a tile with width=nil on a Grid and a ref cell manually to its right, call grid:clear(ax,ay) → ref removed (hits the rightward-scan while-loop at lines 111–119); call grid:clear on a locked tile → no-op (hits the locked guard at line 104). Brings grid.lua 97%→100%.

- [x] Task J — delete dead code in `lua/game/scenes/matrix_scene.lua` — remove the `spec.kind == "arrow"` branch in _place_tile_at (~line 1668, sets w=1,h=1; arrow is not in PALETTE_BUTTONS and is never placed). Dead code removal eliminates the uncovered line.

- [x] Task K — `tests/ui/07_drag_drop.lua` (new UI spec) — open puzzle 1; click_button "Mv"; click_cell on empty cell (no-op); place a pusher on {1,5}; click_button "Mv"; click_cell {1,5} to pick up (ghost); move_mouse to empty cell; click_cell to drop; assert_tile at new position has kind="pusher". Second spec: pick up, move to occupied cell, click → tile stays at origin. Covers matrix_scene drag/drop branches.

- [x] Task L — `tests/ui/08_matrix_scene_ops.lua` (new UI spec, multiple specs) — place and parameterize one op from each uncovered op type: add_matrix, sub_matrix, mul_matrix (click value cells left/right to adjust scalar), set_col (click param cell), scale_col (click band cell), swap_cols. Use puzzles whose palette includes each op. Click param cells (left/right/centre parts) to exercise each distinct handler branch in matrix_scene. Covers op-draw and param-click branches.
