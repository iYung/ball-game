-- Drag-and-drop and timeline behaviour of the puzzle scene, driven through real
-- input (`drag`, psel/chip buttons). Puzzle 1 (Identity Check): pusher at (1,5)
-- pushing right wins in 7 ticks.
local function open_puzzle_1(extra)
    local steps = {
        { press = "return" },
        { click_button = { id = "puzzle:1" } },
        { assert_text = "Identity Check" },
    }
    for _, s in ipairs(extra or {}) do steps[#steps + 1] = s end
    return steps
end

local function with_pusher(extra)
    local steps = open_puzzle_1({
        { drag = { from = { id = "palette:pusher" }, to = { cell = { 1, 5 } } } },
        { assert_tile = { x = 1, y = 5, kind = "pusher" } },
    })
    for _, s in ipairs(extra) do steps[#steps + 1] = s end
    return steps
end

return {
    {
        name  = "drag an op from the ops column onto a grid cell",
        given = { solved = {} },
        steps = open_puzzle_1({
            { drag = { from = { id = "palette:pusher" }, to = { cell = { 3, 3 } } } },
            { assert_tile = { x = 3, y = 3, kind = "pusher" } },
            -- Released over the HUD (not a cell): nothing is placed.
            { drag = { from = { id = "palette:pusher" }, to = { id = "cmd:menu" } } },
            { assert_tile = { x = 4, y = 4 } },
            -- Click-to-select + click-cell still works.
            { click_button = { id = "palette:pusher" } },
            { click_cell = { 5, 5 } },
            { assert_tile = { x = 5, y = 5, kind = "pusher" } },
        }),
    },
    {
        name  = "drag a chip onto the timeline: write, replace same pusher, clear, move",
        given = { solved = {} },
        steps = with_pusher({
            { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
            { assert_text = "A>" },
            -- Same pusher, same tick, other lane: replaces the earlier command.
            { drag = { from = { id = "chip:up" }, to = { slot = { 2, 1 } } } },
            { assert_text = "A^" },
            { assert_no_text = "A>" },
            -- Dropping on an occupied slot replaces it.
            { drag = { from = { id = "chip:left" }, to = { slot = { 2, 1 } } } },
            { assert_text = "A<" },
            { assert_no_text = "A^" },
            -- Drag a filled slot off the bar: cleared.
            { drag = { from = { slot = { 2, 1 } }, to = { cell = { 8, 1 } } } },
            { assert_no_text = "A<" },
            -- Right-click clears too.
            { drag = { from = { id = "chip:down" }, to = { slot = { 3, 2 } } } },
            { assert_text = "Av" },
            { right_click_button = { id = "slot:3:2" } },
            { assert_no_text = "Av" },
            -- Move: right chip from tick 1 to tick 4, then the run takes 3 more ticks.
            { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
            { drag = { from = { slot = { 1, 1 } }, to = { slot = { 1, 4 } } } },
            { assert_text = "A>" },
            { click_button = "Run" },
            { wait_until = { text = "WIN!", max_frames = 3000 } },
            { click_button = "Continue" },
            { assert_text = "SOLVED!" },
            { assert_text = "10" },     -- 3 idle ticks + 7 moving ticks
        }),
    },
    {
        name  = "a command persists: the pusher keeps moving after its chip",
        given = { solved = {} },
        steps = with_pusher({
            { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
            { click_button = "Run" },
            -- Only tick 1 has a command, yet the matrix reaches the sink.
            { wait_until = { text = "WIN!", max_frames = 3000 } },
            { assert_no_text = "STUCK" },
        }),
    },
    {
        name  = "stop chip halts the pusher",
        given = { solved = {} },
        steps = with_pusher({
            { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
            { drag = { from = { id = "chip:stop" }, to = { slot = { 1, 3 } } } },
            { assert_text = "A." },
            { click_button = "Run" },
            { wait_until = { text = "STUCK", max_frames = 3000 } },
            { assert_no_text = "WIN!" },
        }),
    },
    {
        name  = "timeline scrolls to tick 60",
        given = { solved = {} },
        steps = with_pusher({
            { assert_button = { id = "slot:1:60", visible = false } },
            { click_button = { id = "tl:scroll_right" } },
            { click_button = { id = "tl:scroll_right" } },
            { click_button = { id = "tl:scroll_right" } },
            { click_button = { id = "tl:scroll_right" } },
            { click_button = { id = "tl:scroll_right" } },
            { click_button = { id = "tl:scroll_right" } },
            { click_button = { id = "tl:scroll_right" } },
            { assert_button = { id = "tl:scroll_right", enabled = false } },
            { assert_button = { id = "tl:scroll_left",  enabled = true } },
            { assert_button = { id = "slot:1:60", visible = true } },
            { assert_text = "60" },
            { drag = { from = { id = "chip:right" }, to = { slot = { 1, 60 } } } },
            { assert_text = "A>" },
            { click_button = { id = "tl:scroll_left" } },
            { assert_button = { id = "slot:1:60", visible = false } },
        }),
    },
    {
        name  = "psel selector follows pusher erase",
        given = { solved = {} },
        steps = with_pusher({
            { drag = { from = { id = "palette:pusher" }, to = { cell = { 1, 7 } } } },
            { assert_button = { id = "psel:B", visible = true } },
            { click_button = { id = "psel:B" } },
            { assert_button = { id = "psel:B", selected = true } },
            { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
            { assert_text = "B>" },
            -- Erase pusher B from the board: selector and its commands go away.
            { click_button = { id = "palette:erase" } },
            { click_cell = { 1, 7 } },
            { assert_tile = { x = 1, y = 7 } },
            { assert_button = { id = "psel:B", visible = false } },
            { assert_button = { id = "psel:A", selected = true } },
            { assert_no_text = "B>" },
        }),
    },
    {
        name  = "win, Continue, recap replays the new timeline",
        given = { solved = {} },
        steps = with_pusher({
            { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
            { click_button = "Run" },
            { wait_until = { text = "WIN!", max_frames = 3000 } },
            { click_button = "Continue" },
            { assert_text = "SOLVED!" },
            { click_button = "Replay" },
            { wait = 120 },
            { assert_button = { id = "recap:next", visible = true } },
        }),
    },
}
