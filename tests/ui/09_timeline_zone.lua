-- Timeline bar (bottom of the puzzle scene): pusher selector, instruction chips,
-- 4 lanes x 60 ticks, horizontal scroll. Rewritten for the new bar; the old
-- version covered the per-pusher row scroll (tl:scroll_up/down), which no longer
-- exists. The goal is unchanged: the timeline zone is registered, hit-testable
-- (invariants run every frame) and still drawn.

return {
    {
        name  = "timeline controls registered; slots and psel follow pushers",
        given = { solved = {} },
        steps = {
            { press        = "return" },
            { click_button = { id = "puzzle:1" } },
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
        },
    },
    {
        name  = "timeline label still drawn after background draw (regression)",
        given = { solved = {} },
        steps = {
            { press        = "return" },
            { click_button = { id = "puzzle:1" } },
            { assert_text  = "Identity Check" },
            { click_button = "P" },
            { click_cell   = { 3, 3 } },
            -- The bar header (tick numbers) and panel label are still drawn.
            { assert_text  = "INSTRUCTIONS" },
            { assert_text  = "1" },
        },
    },
}
