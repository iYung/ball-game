-- tests/ui/10_matrix_scene_settings.lua
-- Covers matrix_scene.lua lines exercised when the settings overlay is opened
-- via the ESC key while inside a puzzle.
-- Covered paths:
--   key_pressed 'escape' branch (lines 2251-2253)
--   ui_elements delegation when settings is open (lines 1669-1670)
--   update delegation when settings is open (lines 724-726)
--   mouse_pressed delegation when settings is open (lines 1939-1941)
--   key_pressed delegation when settings is open (lines 2244-2246)

local S = require("tests/support/shipped")

return {
    {
        name  = "ESC opens settings overlay in matrix scene; Resume closes it",
        given = { solved = S.before("basics") },
        steps = S.steps({
            { press        = "return" },                        -- title → level select
            S.arrows("basics"),
            { click_button = S.row("identity") },             -- open puzzle 1
            { assert_text  = "Identity Check" },
            { press        = "escape" },                        -- open settings overlay
            { assert_text  = "Settings" },                      -- overlay title drawn
            { assert_button = { id = "settings:resume" } },     -- elements in registry
            { press        = "down" },                          -- settings key delegation
            { click_button = { id = "settings:resume" } },      -- mouse delegation: close
            { assert_text  = "Identity Check" },                -- back in puzzle
        }),
    },
    {
        name  = "Exit to Menu from matrix scene returns to level select",
        given = { solved = S.before("basics") },
        steps = S.steps({
            { press        = "return" },                        -- title → level select
            S.arrows("basics"),
            { click_button = S.row("identity") },             -- open puzzle 1
            { assert_text  = "Identity Check" },
            { press        = "escape" },                        -- open settings overlay
            { assert_text  = "Settings" },
            { click_button = { id = "settings:exit" } },        -- exit via on_exit callback
            { assert_text  = "SELECT PUZZLE" },                 -- back on level select
        }),
    },
}
