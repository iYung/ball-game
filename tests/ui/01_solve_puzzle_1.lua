-- End-to-end: from the title screen, solve puzzle 1 with real input,
-- then follow the recap's Next button into puzzle 2.
return {
    name  = "solve puzzle 1 from the title screen",
    given = { solved = {} },
    steps = {
        { press = "return" },
        { assert_button = { id = "world:1", selected = true } },
        { click_button = "Identity Check" },
        { assert_text = "Identity Check" },
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
        { click_button = "P" },
        { assert_button = { id = "palette:pusher", selected = true } },
        { click_cell = { 1, 5 } },
        { assert_tile = { x = 1, y = 5, kind = "pusher" } },
        -- each slot cycles . ^ > v < ; two clicks set it to ">"
        { click_slot = { pusher = 1, slots = { 1, 2, 3, 4, 5, 6, 7, 8 }, times = 2 } },
        { assert_button = { id = "cmd:run", enabled = true } },
        { click_button = "Run" },
        { assert_button = { id = "cmd:run", enabled = false } },
        { wait_until = { text = "WIN!", max_frames = 3000 } },
        { click_button = "Continue" },
        { assert_text = "SOLVED!" },
        { assert_text = "7" },   -- ticks stat
        { assert_button = { label = "Replay", enabled = true } },
        { assert_button = { label = "Next puzzle", enabled = true } },
        { click_button = "Next puzzle" },
        { assert_text = "Flip It" },
        { assert_button = { id = "cmd:run", enabled = true } },
    },
}
