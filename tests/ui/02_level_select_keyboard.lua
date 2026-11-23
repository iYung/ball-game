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
        name  = "right-click on level select row does nothing",
        given = { solved = {} },
        steps = {
            { press = "return" },                       -- title → level select
            { right_click_button = { id = "puzzle:1" } },  -- btn=2 → early return
            { assert_text = "SELECT PUZZLE" },          -- still on level select
        },
    },
    {
        -- Covers level_select_scene.lua lines exercised when settings overlay is open:
        -- ui_elements delegation, key_pressed delegation, mouse_pressed delegation,
        -- update delegation, and the ESC-to-open path.
        name  = "ESC opens settings overlay in level select; ESC again closes it",
        given = { solved = {} },
        steps = {
            { press = "return" },                           -- title → level select
            { press = "escape" },                           -- open settings overlay
            { assert_text = "Settings" },                   -- overlay title is drawn
            { assert_button = { id = "settings:resume" } }, -- overlay elements in registry
            { press = "down" },                             -- settings key delegation: row 1→2
            { press = "escape" },                           -- close overlay
            { assert_text = "SELECT PUZZLE" },              -- back on level select
        },
    },
}
