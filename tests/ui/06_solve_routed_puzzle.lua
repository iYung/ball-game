-- End-to-end: solve puzzle 3 ("Sharp Left") which requires a right-then-down
-- turn. Source (2,2), wall at y=6 x=1–6, sink (9,8), op: negate.
--
-- Solution:
--   Pusher R at (1,2) pushes the matrix right for 6 slots (ax 2→8).
--   Pusher D at (9,1) is adjacent once matrix reaches ax=8; it pushes
--   the matrix down for 5 slots (ay 2→7, covering sink at (9,8)).
--   Negate op placed at (5,2) fires when the matrix passes through it
--   during the rightward run (anchor (4,2) or (5,2) covers (5,2)).
--
-- Timeline needs 11 slots (6 right + 5 down); extend default 8 by 3.
return {
    name  = "solve puzzle 3 (Sharp Left) end-to-end",
    given = { solved = {} },
    steps = {
        -- Navigate to puzzle 3 from title screen.
        { press = "return" },
        { assert_text = "WORLD 1: BASICS" },
        { click_button = "Sharp Left" },
        { assert_text = "Sharp Left" },

        -- Extend timeline from 8 to 11 slots (click + three times).
        { click_button = { id = "tl:inc" } },
        { click_button = { id = "tl:inc" } },
        { click_button = { id = "tl:inc" } },

        -- Select pusher and place pusher R at (1,2) — left of matrix.
        { click_button = "P" },
        { assert_button = { id = "palette:pusher", selected = true } },
        { click_cell = { 1, 2 } },
        { assert_tile = { x = 1, y = 2, kind = "pusher" } },

        -- Set pusher R (id=1) slots 1–6 to ">" (right).  times=2 cycles . → ^ → >.
        { click_slot = { pusher = 1, slots = { 1, 2, 3, 4, 5, 6 }, times = 2 } },

        -- Place pusher D at (9,1) — above where matrix will be at ax=8.
        { click_button = "P" },
        { click_cell = { 9, 1 } },
        { assert_tile = { x = 9, y = 1, kind = "pusher" } },

        -- Set pusher D (id=2) slots 7–11 to "v" (down).  times=3 cycles . → ^ → > → v.
        { click_slot = { pusher = 2, slots = { 7, 8, 9, 10, 11 }, times = 3 } },

        -- Select negate op and place it at (5,2) on the rightward path.
        { click_button = "-I" },
        { click_cell = { 5, 2 } },

        -- Run and wait for win.
        { assert_button = { id = "cmd:run", enabled = true } },
        { click_button = "Run" },
        { wait_until = { text = "SOLVED!", max_frames = 3000 } },
    },
}
