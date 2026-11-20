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
}
