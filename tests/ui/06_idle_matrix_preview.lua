-- Idle state: input matrix values should be readable (and thus visually present)
-- before any pusher is placed and after a reset.

local S = require("tests/support/shipped")

return {
    name  = "idle matrix preview visible before pusher placed",
    given = { solved = S.before("basics") },
    steps = S.steps({
        -- Navigate to puzzle 1
        { press = "return" },
        { assert_button = { id = "world:1", selected = true } },
        S.arrows("basics"),
        { assert_button = { id = "world:" .. S.world("basics"), selected = true } },
        { click_button = "Identity Check" },
        -- Input matrix is a 2x2 identity: [[1,0],[0,1]]
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
        -- Place a pusher and run to completion
        { click_button = "P" },
        { click_cell = { 1, 5 } },
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { click_button = "Run" },
        { wait_until = { text = "WIN!", max_frames = 3000 } },
        -- Reset returns to idle; input matrix should still be readable
        { click_button = "Reset" },
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
    }),
}
