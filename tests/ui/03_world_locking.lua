-- Locked worlds are skipped; an unlocked world is reachable and playable.
return {
    {
        name  = "locked worlds are skipped",
        given = { solved = {} },
        steps = {
            { press = "return" },
            { press = "right" },
            { assert_text = "WORLD 1: BASICS" },
            { assert_no_text = "WORLD 2" },
        },
    },
    {
        name  = "world 2 unlocks after world 1",
        given = { solved = { 1, 2, 3, 4, 5 } },
        steps = {
            { press = "return" },
            { press = "right" },
            { assert_text = "WORLD 2: COMBOS" },
            { click_button = { id = "puzzle:6" } },
            { assert_text = "Row Swap" },
        },
    },
}
