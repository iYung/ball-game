-- The recap of a two-source win through real input: the replay shows both inputs,
-- then only their sum, whether the merge is mid-run or on the very last tick.

local function from_def(def)
    return function(sm)
        return require("lua/game/scenes/matrix_scene").new_from_def(def, sm)
    end
end

local A = { { 1, 2 }, { 3, 4 } }
local B = { { 10, 20 }, { 30, 40 } }
local SUM = { { 11, 22 }, { 33, 44 } }

-- A at (2,3) and B at (6,3) meet on the locked M+ at (4,3)/(5,3) on tick 1.
local function add_def(sink)
    return {
        name = "Pair Sum", grid_w = 10, grid_h = 10,
        source  = { x = 2, y = 3 }, input  = { rows = 2, cols = 2, values = A },
        source2 = { x = 6, y = 3 }, input2 = { rows = 2, cols = 2, values = B },
        sink    = sink,
        target  = { rows = 2, cols = 2, values = SUM },
        locked  = { { kind = "op", op = "matrix_add", x = 4, y = 3 } },
        ops     = {},
    }
end

-- Pusher A left of source 1 moving right, pusher B right of source 2 moving left,
-- then Run to a win and Continue to the recap.
local function win_to_recap(extra)
    local steps = {
        { click_button = { id = "palette:pusher" } },
        { click_cell = { 1, 3 } },
        { click_cell = { 8, 3 } },
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { click_button = { id = "psel:B" } },
        { drag = { from = { id = "chip:left" }, to = { slot = { 2, 1 } } } },
    }
    local function add(list)
        for _, s in ipairs(list) do steps[#steps + 1] = s end
    end
    add(extra.before_run or {})
    add({
        { click_button = "Run" },
        { wait_until = { text = "WIN!", max_frames = 600 } },
        { click_button = "Continue" },
        { assert_text = "SOLVED!" },
        { assert_text = "SRC 1" },
        { assert_text = "SRC 2" },
        { assert_text = "M+" },
        { click_button = "Replay" },
        -- Replay starts over with both inputs on their way in.
        { assert_text = "40" },
        { assert_no_text = "44" },
        { wait_until = { text = "44", max_frames = 60 } },
        { assert_no_text = "40" },
    })
    add(extra.after)
    return steps
end

return {
    {
        name = "recap of a merge before the last tick",
        make_scene = from_def(add_def({ x = 6, y = 4 })),
        steps = win_to_recap({
            -- B's pusher stops after the merge so only A carries the sum on.
            before_run = { { drag = { from = { id = "chip:stop" }, to = { slot = { 1, 2 } } } } },
            after = {
                -- The sum travels on, holds, and the loop shows both inputs again.
                { wait = 30 },
                { assert_text = "44" },
                { assert_no_text = "40" },
                { wait_until = { text = "40", max_frames = 120 } },
                { assert_no_text = "44" },
                { click_button = "Replay" },
                { assert_text = "40" },
                { assert_text = "SOLVED!" },
            },
        }),
    },
    {
        name = "recap of a merge on the last tick holds on the result",
        make_scene = from_def(add_def({ x = 4, y = 4 })),
        steps = win_to_recap({
            after = {
                -- Still the result well into the end hold, then it loops.
                { wait = 25 },
                { assert_text = "44" },
                { assert_no_text = "40" },
                { wait_until = { text = "40", max_frames = 60 } },
                { assert_no_text = "44" },
                { click_button = "Replay" },
                { assert_text = "40" },
                { wait_until = { text = "44", max_frames = 60 } },
            },
        }),
    },
}
