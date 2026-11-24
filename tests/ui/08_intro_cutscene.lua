-- tests/ui/08_intro_cutscene.lua
-- Covers the intro cutscene (world 0) that fires on the first visit to level select.
-- world_0.lua has 3 beats, speaker "SYSTEM", last beat text "MATRIX PUSH — BEGIN".

return {
    {
        name  = "first visit: pressing enter on title triggers intro cutscene",
        given = { cutscenes_unseen = { 0 } },
        steps = {
            { press = "return" },                        -- title → intro cutscene
            { assert_text = "SYSTEM" },                  -- first beat speaker
            { press = "return" },                        -- advance to beat 2
            { assert_text = "SYSTEM" },
            { press = "return" },                        -- advance to beat 3
            { assert_text = "MATRIX PUSH" },            -- last beat text
            { press = "return" },                        -- advance past final beat → level select
            { assert_text = "SELECT PUZZLE" },           -- landed on level select
        },
    },
    {
        name  = "second visit: title goes straight to level select",
        given = {},                                      -- intro already marked seen by default
        steps = {
            { press = "return" },                        -- title → level select (no cutscene)
            { assert_text = "SELECT PUZZLE" },
        },
    },
    {
        name  = "escape on intro cutscene skips to level select",
        given = { cutscenes_unseen = { 0 } },
        steps = {
            { press = "return" },                        -- title → intro cutscene
            { assert_text = "SYSTEM" },
            { press = "escape" },                        -- skip → level select
            { assert_text = "SELECT PUZZLE" },
        },
    },
    {
        name  = "click on title triggers intro cutscene on first visit",
        given = { cutscenes_unseen = { 0 } },
        steps = {
            { click_button = { id = "start:play" } },    -- click Play → intro cutscene
            { assert_text = "SYSTEM" },
            { press = "escape" },                        -- skip → level select
            { assert_text = "SELECT PUZZLE" },
        },
    },
}
