-- Timeline bar (bottom of the puzzle scene): pusher selector, instruction chips,
-- 4 lanes x 60 ticks, horizontal scroll. Rewritten for the new bar; the old
-- version covered the per-pusher row scroll (tl:scroll_up/down), which no longer
-- exists. The goal is unchanged: the timeline zone is registered, hit-testable
-- (invariants run every frame) and still drawn.

local S = require("tests/support/shipped")

return {
    {
        name  = "timeline controls registered; slots and psel follow pushers",
        given = { solved = S.before("basics") },
        steps = S.steps({
            { press        = "return" },
            S.arrows("basics"),
            { click_button = S.row("identity") },
            { assert_text  = "Identity Check" },

            -- No pusher yet: no selector buttons, scroll-left disabled at the start.
            { assert_button = { id = "psel:A", visible = false } },
            { assert_button = { id = "tl:scroll_left",  enabled = false } },
            { assert_button = { id = "tl:scroll_right", enabled = true } },
            { assert_button = { id = "chip:right", enabled = true } },
            { assert_button = { id = "slot:4:1",   enabled = true } },

            { click_button = "P" },
            { click_cell   = { 5, 5 } },
            { assert_tile  = { x = 5, y = 5, kind = "pusher" } },
            { assert_button = { id = "psel:A", selected = true } },
        }),
    },
    {
        name  = "CLR chip registered; arms and clears a filled slot",
        given = { solved = S.before("basics") },
        steps = S.steps({
            { press        = "return" },
            S.arrows("basics"),
            { click_button = S.row("identity") },
            { assert_text  = "Identity Check" },
            { click_button = "P" },
            { click_cell   = { 3, 3 } },
            { assert_button = { id = "chip:clear", enabled = true } },

            -- Fill a slot, then clear it with the CLR chip.
            { click_button = { id = "chip:right" } },
            { click_button = { id = "slot:1:2" } },
            { click_button = { id = "chip:clear" } },
            { assert_button = { id = "chip:clear", selected = true } },
            { click_button = { id = "slot:1:2" } },
            { assert_slot  = { lane = 1, tick = 2, empty = true } },
        }),
    },
    {
        name  = "timeline label still drawn after background draw (regression)",
        given = { solved = S.before("basics") },
        steps = S.steps({
            { press        = "return" },
            S.arrows("basics"),
            { click_button = S.row("identity") },
            { assert_text  = "Identity Check" },
            { click_button = "P" },
            { click_cell   = { 3, 3 } },
            -- The bar header (tick numbers) and panel label are still drawn.
            { assert_text  = "INSTRUCTIONS" },
            { assert_text  = "1" },
        }),
    },
}
