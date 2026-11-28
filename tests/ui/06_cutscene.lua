-- tests/ui/06_cutscene.lua
-- Covers CutsceneScene (cutscene_scene.lua) end-to-end.
-- The Combos cutscene has 3 beats, all speaker "SYSTEM".

local S = require("tests/support/shipped")

return {
    {
        name  = "navigate to world 2 triggers cutscene",
        given = { solved = S.before("combos"), cutscenes_unseen = { S.world("combos") } },
        steps = S.steps({
            { press = "return" },                       -- title → level select (world 1)
            S.arrows("combos"),                         -- cycle to Combos → cutscene loads
            { assert_text = "SYSTEM" },                 -- first beat speaker is drawn
            { assert_text = "Warm-up complete. The patterns here will not yield to a straight push." },
            { press = "return" },                       -- advance to beat 2
            { assert_text = "SYSTEM" },
            { press = "return" },                       -- advance to beat 3
            { assert_text = "WORLD 2: COMBOS" },        -- beat 3 text
            { press = "return" },                       -- advance past final beat → level select (Combos)
            { assert_text = "Top Only" },            -- unique to Combos (top_only)
        }),
    },
    {
        name  = "escape skips cutscene and returns to level select",
        given = { solved = S.before("combos"), cutscenes_unseen = { S.world("combos") } },
        steps = S.steps({
            { press = "return" },                       -- title → level select
            S.arrows("combos"),                         -- cycle to Combos → cutscene loads
            { assert_text = "SYSTEM" },
            { press = "escape" },                       -- skip → level select (Combos)
            { assert_text = "Top Only" },
        }),
    },
    {
        name  = "click world:2 tab triggers cutscene (first visit)",
        given = { solved = S.before("combos"), cutscenes_unseen = { S.world("combos") } },
        steps = {
            { press = "return" },                       -- title → level select (world 1)
            { click_button = S.tab("combos") },        -- click tab → cutscene (mouse path)
            { assert_text = "SYSTEM" },                 -- first beat speaker is drawn
            { press = "escape" },                       -- skip → level select (world 2)
            { assert_text = "Top Only" },            -- unique to world 2
        },
    },
    {
        -- Regression: pressing U to unlock a world also resets the cutscene-seen
        -- flag for the newly-accessible world.  Without this, testers who had
        -- previously seen the cutscene would press U and get no cutscene.
        name  = "pressing u to unlock world 1 resets world 2 cutscene",
        -- no cutscenes_unseen → all pre-marked seen
        given = { solved = S.before(S.world("combos") - 1) },
        steps = S.steps({
            { press = "return" },                       -- title → level select (world 1)
            S.arrows(S.world("combos") - 1),            -- the world before Combos
            { press = "u" },                            -- unlock it → clears the Combos seen flag
            { click_button = S.tab("combos") },         -- tab now enabled; cutscene should fire
            { assert_text = "SYSTEM" },
            { press = "escape" },
            { assert_text = "Top Only" },
        }),
    },
}
