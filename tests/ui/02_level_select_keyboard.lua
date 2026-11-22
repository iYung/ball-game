-- Regression: a cursor resting over a row must not override Up/Down.
return {
    {
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
    },
    {
        name  = "level select left-arrow and u-key",
        given = { solved = "all" },
        steps = {
            { press = "return" },                                   -- title → level select (world 1)
            { press = "right" },                                    -- world 1 → world 2
            { press = "left" },                                     -- world 2 → world 1
            { assert_button = { id = "puzzle:1", visible = true } }, -- world 1 puzzles shown
            { press = "u" },                                        -- debug unlock: unlock_world fires, no crash
            { assert_button = { id = "puzzle:1", visible = true } }, -- scene still showing world 1
        },
    },
    {
        name  = "escape on level select returns to start screen",
        given = { solved = {} },
        steps = {
            { press = "return" },                       -- title → level select
            { press = "escape" },                       -- level select → start screen
            { assert_button = { id = "start:play", visible = true } }, -- start screen is shown
        },
    },
    {
        name  = "right-click on level select row does nothing",
        given = { solved = {} },
        steps = {
            { press = "return" },                       -- title → level select
            { right_click_button = { id = "puzzle:1" } },  -- btn=2 → early return
            { assert_text = "SELECT PUZZLE" },          -- still on level select
        },
    },
}
