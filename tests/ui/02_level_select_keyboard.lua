-- Regression: a cursor resting over a row must not override Up/Down.

local S = require("tests/support/shipped")

return {
    {
        name  = "level select keyboard nav with cursor parked on a row",
        given = { solved = S.before("combos") },
        steps = S.steps({
            { press = "return" },
            S.arrows("combos"),
            { hover_button = S.row("corner_case") },                -- "Corner Case"
            { press = "down" },
            { assert_button = { id = "puzzle:" .. (S.puzzle("corner_case") + 1), selected = true } },
            { wait = 30 },
            { assert_button = { id = "puzzle:" .. (S.puzzle("corner_case") + 1), selected = true } },
            { press = "up" },
            { press = "up" },
            { assert_button = { id = "puzzle:" .. (S.puzzle("corner_case") - 1), selected = true } },
            { press = "return" },
            { assert_text = S.name_after("corner_case", -1) },
        }),
    },
    {
        name  = "level select left-arrow and u-key",
        given = { solved = "all" },
        steps = S.steps({
            { press = "return" },                                   -- title → level select (world 1)
            S.arrows("basics"),
            { press = "right" },                                    -- Basics → next world
            { press = "left" },                                     -- back to Basics
            { assert_button = { id = S.row("identity").id, visible = true } }, -- Basics puzzles shown
            { press = "u" },                                        -- debug unlock: unlock_world fires, no crash
            { assert_button = { id = S.row("identity").id, visible = true } }, -- scene still showing Basics
        }),
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
        name  = "ESC opens settings overlay in level select; Resume click closes it",
        given = { solved = {} },
        steps = {
            { press = "return" },                           -- title → level select
            { press = "escape" },                           -- open settings overlay
            { assert_text = "Settings" },                   -- overlay title is drawn
            { assert_button = { id = "settings:resume" } }, -- overlay elements in registry (ui_elements delegation)
            { press = "down" },                             -- settings key delegation: row 1→2
            { click_button = { id = "settings:resume" } }, -- mouse_pressed delegation → closes overlay
            { assert_text = "SELECT PUZZLE" },              -- back on level select
        },
    },
}
