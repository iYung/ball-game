-- tests/ui/06_cutscene.lua
-- Covers CutsceneScene (cutscene_scene.lua) end-to-end.
-- world_2.lua has 3 beats, all speaker "SYSTEM".

return {
    {
        name  = "navigate to world 2 triggers cutscene",
        given = { solved = { 1, 2, 3, 4, 5 }, cutscenes_unseen = { 2 } },
        steps = {
            { press = "return" },                       -- title → level select (world 1)
            { press = "right" },                        -- cycle to world 2 → cutscene loads
            { assert_text = "SYSTEM" },                 -- first beat speaker is drawn
            { press = "return" },                       -- advance to beat 2
            { assert_text = "SYSTEM" },
            { press = "return" },                       -- advance to beat 3
            { assert_text = "WORLD 2: COMBOS" },        -- beat 3 text
            { press = "return" },                       -- advance past final beat → level select (world 2)
            { assert_text = "Ordered Ops" },            -- unique to world 2 (puzzle 7)
        },
    },
    {
        name  = "escape skips cutscene and returns to level select",
        given = { solved = { 1, 2, 3, 4, 5 }, cutscenes_unseen = { 2 } },
        steps = {
            { press = "return" },                       -- title → level select
            { press = "right" },                        -- cycle to world 2 → cutscene loads
            { assert_text = "SYSTEM" },
            { press = "escape" },                       -- skip → level select (world 2)
            { assert_text = "Ordered Ops" },
        },
    },
    {
        name  = "click world:2 tab triggers cutscene (first visit)",
        given = { solved = { 1, 2, 3, 4, 5 }, cutscenes_unseen = { 2 } },
        steps = {
            { press = "return" },                       -- title → level select (world 1)
            { click_button = { id = "world:2" } },     -- click tab → cutscene (mouse path)
            { assert_text = "SYSTEM" },                 -- first beat speaker is drawn
            { press = "escape" },                       -- skip → level select (world 2)
            { assert_text = "Ordered Ops" },            -- unique to world 2
        },
    },
    {
        -- Regression: pressing U to unlock a world also resets the cutscene-seen
        -- flag for the newly-accessible world.  Without this, testers who had
        -- previously seen the cutscene would press U and get no cutscene.
        name  = "pressing u to unlock world 1 resets world 2 cutscene",
        given = { solved = {} },                        -- no cutscenes_unseen → all pre-marked seen
        steps = {
            { press = "return" },                       -- title → level select (world 1)
            { press = "u" },                            -- unlock world 1 → clears world 2 seen flag
            { click_button = { id = "world:2" } },     -- tab now enabled; cutscene should fire
            { assert_text = "SYSTEM" },
            { press = "escape" },
            { assert_text = "Ordered Ops" },
        },
    },
}
