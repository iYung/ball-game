-- End-to-end: solve puzzle 3 ("Scale and Shift"), which takes a U-shaped route.
-- Source (2,2), wall at x=5 y=1-6, sink (9,3), ops: scalar_mul and scalar_add.
--
-- Solution:
--   Pusher A at (2,1) pushes the matrix down from tick 1.
--   Pusher B at (1,7) pushes it right from tick 6, under the wall.
--   Pusher C at (9,9) pushes it up from tick 12 onto the sink. WIN at tick 15.
--   A scalar_mul tile set to x3 at (2,5) fires on the way down, then a scalar_add
--   tile set to +4 at (5,7) fires on the way right.
--
-- Commands persist: each pusher gets 'stop' on lane 1 of the tick where the next
-- one starts on lane 2.

local S = require("tests/support/shipped")

return {
    name  = "solve puzzle 3 (Scale and Shift) end-to-end",
    given = { solved = S.before("basics") },
    steps = S.steps({
        -- Navigate to puzzle 3 from title screen.
        { press = "return" },
        { assert_button = { id = "world:1", selected = true } },
        S.arrows("basics"),
        { assert_button = { id = "world:" .. S.world("basics"), selected = true } },
        { click_button = "Scale and Shift" },
        { assert_text = "Scale and Shift" },

        -- Select pusher and place pusher A at (2,1) -- above the matrix.
        { click_button = "P" },
        { assert_button = { id = "palette:pusher", selected = true } },
        { click_cell = { 2, 1 } },
        { assert_tile = { x = 2, y = 1, kind = "pusher" } },

        -- Pusher A (selected automatically): 'down' at tick 1.
        { drag = { from = { id = "chip:down" }, to = { slot = { 1, 1 } } } },

        -- Place pushers B at (1,7) and C at (9,9).
        { click_button = "P" },
        { click_cell = { 1, 7 } },
        { assert_tile = { x = 1, y = 7, kind = "pusher" } },
        { click_button = "P" },
        { click_cell = { 9, 9 } },
        { assert_tile = { x = 9, y = 9, kind = "pusher" } },

        -- At tick 6 send B right (lane 2) and stop A (lane 1).
        { click_button = { id = "psel:B" } },
        { drag = { from = { id = "chip:right" }, to = { slot = { 2, 6 } } } },
        { click_button = { id = "psel:A" } },
        { drag = { from = { id = "chip:stop" }, to = { slot = { 1, 6 } } } },

        -- At tick 12 send C up (lane 2) and stop B (lane 1).
        { click_button = { id = "psel:C" } },
        { drag = { from = { id = "chip:up" }, to = { slot = { 2, 12 } } } },
        { click_button = { id = "psel:B" } },
        { drag = { from = { id = "chip:stop" }, to = { slot = { 1, 12 } } } },

        -- Place a scalar_mul tile at (2,5) on the downward path and raise k from
        -- 2 to 3 with one click on its right third.
        { click_button = { id = "palette:scalar_mul" } },
        { click_cell = { 2, 5 } },
        { click_cell = { 2, 5, part = "right" } },
        { assert_tile = { x = 2, y = 5, kind = "op", op = "scalar_mul", scalar = 3 } },
        { assert_text = "x3" },

        -- Place a scalar_add tile at (5,7) on the rightward path and raise k from
        -- 1 to 4 with three clicks on its right third.
        { click_button = { id = "palette:scalar_add" } },
        { click_cell = { 5, 7 } },
        { click_cell = { 5, 7, part = "right" } },
        { click_cell = { 5, 7, part = "right" } },
        { click_cell = { 5, 7, part = "right" } },
        { assert_tile = { x = 5, y = 7, kind = "op", op = "scalar_add", scalar = 4 } },
        { assert_text = "+4" },

        -- Run and wait for win.
        { assert_button = { id = "cmd:run", enabled = true } },
        { click_button = "Run" },
        { wait_until = { text = "WIN!", max_frames = 3000 } },
        { click_button = "Continue" },
        { assert_text = "SOLVED!" },
    }),
}
