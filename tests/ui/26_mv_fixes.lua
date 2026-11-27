-- Mv (drag) tool: lifting a pusher keeps its commands and selection, Run while
-- holding a tile puts it back first, and Mv never places a tile during a run.

local S = require("tests/support/shipped")

local function open(steps)
    local out = S.steps({
        { press = "return" },
        S.arrows("combos"),
        { click_button = S.row("set_row") },
        { click_button = "P" },
        { click_cell = { 1, 5 } },
        { click_button = "P" },
        { click_cell = { 1, 7 } },
        { click_button = { id = "psel:B" } },
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 3 } } } },
        { click_button = "Mv" },
    })
    for _, step in ipairs(steps) do out[#out + 1] = step end
    return out
end

local command = { assert_slot = { lane = 1, tick = 3, pusher = 2, cmd = "right" } }
local selected = { assert_button = { id = "psel:B", selected = true } }

return {
    {
        name  = "moving a pusher keeps its commands and selection",
        given = { solved = S.before("combos") },
        steps = open({
            { mouse_down = { id = "cell:1,7" } },
            { assert_tile = { x = 1, y = 7 } },
            command,   -- its selector button is hidden while it is off the board
            { mouse_up = { id = "cell:2,8" } },
            { assert_tile = { x = 2, y = 8, kind = "pusher" } },
            command, selected,
        }),
    },
    {
        name  = "Run while holding a pusher puts it back first",
        given = { solved = S.before("combos") },
        steps = open({
            { mouse_down = { id = "cell:1,7" } },
            { press = "r" },
            { assert_tile = { x = 1, y = 7, kind = "pusher" } },
            command,
            { mouse_up = { id = "cell:2,8" } },
            { assert_tile = { x = 2, y = 8 } },
        }),
    },
    {
        name  = "Mv places nothing on an empty cell during a run",
        given = { solved = S.before("combos") },
        steps = open({
            { click_button = "Run" },
            { click_cell = { 3, 9 } },
            { assert_tile = { x = 3, y = 9 } },
        }),
    },
}
