# Matrix Circuit Checklist

- [x] Task 1 — `game/matrix_math.lua` — Pure-Lua matrix type and 6 operations: new(rows,cols,values), transpose, scale_row(r,s), add_rows(src,dst,s), swap_rows(a,b), negate, scalar_mul(s), plus an equals(other) comparator and a copy() method. No Love2D dependency.

- [x] Task 2 — `data/puzzles/01_identity.lua` through `data/puzzles/10_elimination.lua` — Ten puzzle data files using the schema in the design doc (name, grid_w/h, source, sink, input, target, optional locked tiles). Cover the 10 progression steps from the design doc.

- [x] Task 3 — `game/puzzle_loader.lua` — Load a puzzle file by index, return a validated puzzle table. Expose `load(n)` returning the table, or error with a clear message.

- [x] Task 4 — `game/grid.lua` — 10×10 tile grid. Each cell holds a tile type (`arrow`, `op`) or nil. API: `new(w,h)`, `set(x,y,tile)`, `get(x,y)`, `clear(x,y)`, `clear_all()`. Tile is a table `{kind, dir|op_type, params}`.

- [x] Task 5 — `game/cursor.lua` — Cursor that walks the grid. API: `new(grid, start_x, start_y, start_dir)`, `step(matrix)` → applies op at current cell then moves one step, returns `"ok"`, `"sink"`, `"loop"`, or `"out_of_bounds"`. Tracks visited cells to detect loops.

- [x] Task 6 — `game/palette.lua` — Palette bar state (not drawing). Tracks selected tile type + direction/op. API: `new()`, `select(tile_spec)`, `selected()`. Tile specs: arrows (`arrow,right` etc.) and ops (`op,transpose` etc.).

- [x] Task 7 — `game/param_popup.lua` — Parameter editor drawn with love.graphics. Shows a small overlay panel when an op tile needs configuration (row indices, scalar). API: `new()`, `open(op_type, current_params, on_confirm_cb)`, `close()`, `update(dt)`, `draw()`, `mouse_pressed(x,y,btn)`, `key_pressed(key)`. Calls on_confirm_cb(params) when player confirms.

- [x] Task 8 — `game/hud.lua` — Right-panel HUD drawn with love.graphics. Draws labelled matrix panels for input, target, and current state. API: `new(x, y, w, h)`, `draw(input_mat, target_mat, current_mat)`. Numbers in clean grid cells, label above each panel.

- [x] Task 9 — `game/scenes/matrix_scene.lua` — Main scene wiring everything together. Uses Scene base. `on_enter` loads puzzle, creates grid/cursor/palette/hud. `update(dt)` handles run animation timer and input. `draw()` renders grid tiles, cursor highlight, palette bar, hud, and win/fail overlay. Handles mouse (place/erase tiles, palette clicks) and keyboard (R=run, Space=step, Backspace=reset, left/right arrows = prev/next puzzle).

- [x] Task 10 — `main.lua` + `conf.lua` — Change initial scene to `MatrixScene` (puzzle 1). Update window title to `"Matrix Circuit"`.
