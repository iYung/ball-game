-- End-to-end: solve puzzle 3 ("Sharp Left") which requires a right-then-down
-- turn. Source (2,2), wall at y=6 x=1–6, sink (9,8), op: scalar_mul.
--
-- Solution:
--   Pusher R at (1,2) pushes the matrix right for 6 slots (ax 2→8).
--   Pusher D at (9,1) is adjacent once matrix reaches ax=8; it pushes
--   the matrix down for 5 slots (ay 2→7, covering sink at (9,8)).
--   A scalar_mul tile set to x-1 at (5,2) fires when the matrix passes through
--   it during the rightward run (anchor (4,2) or (5,2) covers (5,2)).
--
-- Commands persist: A gets 'right' at tick 1 and 'stop' at tick 7, B gets
-- 'down' at tick 7 (held until the end of the run).
return {
    name  = "solve puzzle 3 (Sharp Left) end-to-end",
    given = { solved = {} },
    steps = {
        -- Navigate to puzzle 3 from title screen.
        { press = "return" },
        { assert_button = { id = "world:1", selected = true } },
        { click_button = "Sharp Left" },
        { assert_text = "Sharp Left" },

        -- Select pusher and place pusher R at (1,2) — left of matrix.
        { click_button = "P" },
        { assert_button = { id = "palette:pusher", selected = true } },
        { click_cell = { 1, 2 } },
        { assert_tile = { x = 1, y = 2, kind = "pusher" } },

        -- Pusher A (selected automatically): 'right' at tick 1.
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },

        -- Place pusher D at (9,1) — above where matrix will be at ax=8.
        { click_button = "P" },
        { click_cell = { 9, 1 } },
        { assert_tile = { x = 9, y = 1, kind = "pusher" } },

        -- Select pusher B; at tick 7 stop A (lane 1) and send B down (lane 2).
        { click_button = { id = "psel:B" } },
        { drag = { from = { id = "chip:down" }, to = { slot = { 2, 7 } } } },
        { click_button = { id = "psel:A" } },
        { drag = { from = { id = "chip:stop" }, to = { slot = { 1, 7 } } } },

        -- Place a scalar_mul tile at (5,2) on the rightward path and lower k from
        -- 2 to -1 with three clicks on its left third.
        { click_button = { id = "palette:scalar_mul" } },
        { click_cell = { 5, 2 } },
        { click_cell = { 5, 2, part = "left" } },
        { click_cell = { 5, 2, part = "left" } },
        { click_cell = { 5, 2, part = "left" } },
        { assert_tile = { x = 5, y = 2, kind = "op", op = "scalar_mul", scalar = -1 } },
        { assert_text = "x-1" },

        -- Run and wait for win.
        { assert_button = { id = "cmd:run", enabled = true } },
        { click_button = "Run" },
        { wait_until = { text = "WIN!", max_frames = 3000 } },
        { click_button = "Continue" },
        { assert_text = "SOLVED!" },
    },
}
