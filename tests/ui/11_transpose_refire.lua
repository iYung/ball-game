-- Regression: pushing a 3×2 matrix onto a T op transposes it to 2×3, moving it off
-- the T tile. Pushing back onto T must fire T again (double transpose = identity).
--
-- Setup (puzzle 5, Squeeze Bend, rows=2 cols=3 input, transpose-only ops):
--   T op at (7,3); pusher A at (1,3) given one right chip at tick 1 (the command persists).
--   Path: source (2,3) → ticks 1–3 matrix reaches (5,3) [T fires, becomes 3×2]
--         → tick 4 matrix at (6,3) [T fires again, becomes 2×3 = original values]
--   After tick 4 current_matrix must equal {{1,2,3},{4,5,6}}.
return {
    name  = "transpose re-arms after matrix dimension shrinks off the tile",
    given = { solved = {1, 2, 3, 4} },
    steps = {
        { press = "return" },
        { click_button = { id = "puzzle:5" } },
        { assert_text = "Squeeze Bend" },

        -- Place transpose op at (7,3).
        { click_button = { id = "palette:transpose" } },
        { click_cell   = { 7, 3 } },
        { assert_tile  = { x = 7, y = 3, kind = "op" } },

        -- Place pusher at (1,3).
        { click_button = { id = "palette:pusher" } },
        { click_cell   = { 1, 3 } },
        { assert_tile  = { x = 1, y = 3, kind = "pusher" } },

        -- Drag one 'right' chip to tick 1; the pusher keeps moving right.
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },

        -- Run; first wait for the transposed state (T fired once), then verify T
        -- fires again to restore the original matrix (double-transpose = identity).
        { click_button = "Run" },
        { wait_until   = { matrix = {{1,4},{2,5},{3,6}}, max_frames = 500 } },
        { wait_until   = { matrix = {{1,2,3},{4,5,6}}, max_frames = 500 } },
    },
}
