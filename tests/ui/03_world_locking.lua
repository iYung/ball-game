-- Locked worlds are skipped; an unlocked world is reachable and playable.
return {
    {
        name  = "locked worlds are skipped",
        given = { solved = {} },
        steps = {
            { press = "return" },
            { press = "right" },
            { assert_button = { id = "world:1", selected = true } },
            { assert_button = { id = "world:2", selected = false } },
        },
    },
    {
        name  = "world 2 unlocks after world 1",
        given = { solved = { 1, 2, 3, 4, 5 } },
        steps = {
            { press = "return" },
            { press = "right" },
            { assert_button = { id = "world:2", selected = true } },
            { click_button = { id = "puzzle:6" } },
            { assert_text = "Z-Bend" },
        },
    },
}
