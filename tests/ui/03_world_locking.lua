-- Locked worlds are skipped; an unlocked world is reachable and playable.

local S = require("tests/support/shipped")

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
        given = { solved = S.before("combos") },
        steps = S.steps({
            { press = "return" },
            S.arrows("combos"),
            { assert_button = { id = S.tab("combos").id, selected = true } },
            { click_button = S.row("row_swap") },
            { assert_text = "Z-Bend" },
        }),
    },
}
