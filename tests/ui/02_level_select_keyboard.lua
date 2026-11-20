-- Regression: a cursor resting over a row must not override Up/Down.
return {
    name  = "level select keyboard nav with cursor parked on a row",
    given = { solved = {} },
    steps = {
        { press = "return" },
        { hover_button = "Sharp Left" },
        { press = "down" },
        { assert_button = { id = "puzzle:4", selected = true } },
        { wait = 30 },
        { assert_button = { id = "puzzle:4", selected = true } },
        { press = "up" },
        { press = "up" },
        { assert_button = { id = "puzzle:2", selected = true } },
        { press = "return" },
        { assert_text = "Flip It" },
    },
}
