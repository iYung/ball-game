-- Regression: the matrix slides into an op with its pre-op values; the transform
-- shows once it has arrived (matches the solution recap).
return {
    name  = "matrix shows pre-op values while sliding into an op",
    given = { solved = {} },
    steps = {
        { press = "return" },
        { click_button = { id = "puzzle:2" } },
        { assert_text = "Flip It" },
        { click_button = { id = "palette:transpose" } },
        { click_cell = { 5, 6 } },
        { assert_tile = { x = 5, y = 6, kind = "op", op = "transpose" } },
        { click_button = { id = "palette:pusher" } },
        { click_cell = { 1, 5 } },
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { click_button = "Run" },
        -- ~0.35 s per tick: 30 frames in is the middle of the slide into the transpose tile.
        { wait = 30 },
        { assert_matrix = { { 1, 2 }, { 3, 4 } } },
        { wait_until = { matrix = { { 1, 3 }, { 2, 4 } }, max_frames = 120 } },
        { assert_matrix = { { 1, 3 }, { 2, 4 } } },
    },
}
