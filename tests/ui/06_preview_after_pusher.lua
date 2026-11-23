-- Placing a pusher with real clicks leaves the idle board intact; Reset returns to idle.
return {
    name  = "place pusher then reset keeps idle matrix",
    given = { solved = {} },
    steps = {
        { press = "return" },
        { assert_button = { id = "world:1", selected = true } },
        { click_button = "Identity Check" },
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
        { click_button = "P" },
        { click_cell = { 1, 5 } },
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
        { click_slot = { pusher = 1, slots = { 1, 2, 3, 4, 5, 6, 7, 8 }, times = 2 } },
        { click_button = "Run" },
        { wait_until = { text = "WIN!", max_frames = 3000 } },
        { click_button = "Reset" },
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
    },
}
