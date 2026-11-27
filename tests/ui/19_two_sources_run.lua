-- Two-source puzzles through real input: both previews, a merge watched as it
-- happens and won through to the recap, the shape-mismatch banner, and Reset.

local function from_def(def)
    return function(sm)
        return require("lua/game/scenes/matrix_scene").new_from_def(def, sm)
    end
end

local A = { { 1, 2 }, { 3, 4 } }
local B = { { 10, 20 }, { 30, 40 } }
local SUM = { { 11, 22 }, { 33, 44 } }
local WIDE = { { 1, 2, 3 }, { 4, 5, 6 } }

-- A at (2,3) and B at (6,3) meet on the locked M+ at (4,3)/(5,3).
local add_def = {
    name = "Pair Sum", grid_w = 10, grid_h = 10,
    source  = { x = 2, y = 3 }, input  = { rows = 2, cols = 2, values = A },
    source2 = { x = 6, y = 3 }, input2 = { rows = 2, cols = 2, values = B },
    sink    = { x = 6, y = 4 },
    target  = { rows = 2, cols = 2, values = SUM },
    locked  = { { kind = "op", op = "matrix_add", x = 4, y = 3 } },
    ops     = {},
}

local mul_def = {
    name = "Bad Product", grid_w = 10, grid_h = 10,
    source  = { x = 2, y = 3 }, input  = { rows = 2, cols = 3, values = WIDE },
    source2 = { x = 7, y = 3 }, input2 = { rows = 2, cols = 2, values = A },
    sink    = { x = 10, y = 10 },
    target  = { rows = 2, cols = 2, values = A },
    locked  = { { kind = "op", op = "matrix_mul", x = 5, y = 3, params = { facing = "right" } } },
    ops     = {},
}

-- Pusher A left of source 1 moving right, pusher B right of source 2 moving left.
local function two_pushers(bx, extra)
    local steps = {
        { click_button = { id = "palette:pusher" } },
        { click_cell = { 1, 3 } },
        { click_cell = { bx, 3 } },
        { assert_tile = { x = bx, y = 3, kind = "pusher" } },
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { click_button = { id = "psel:B" } },
        { drag = { from = { id = "chip:left" }, to = { slot = { 2, 1 } } } },
    }
    for _, s in ipairs(extra) do steps[#steps + 1] = s end
    return steps
end

local previews = { { x = 2, y = 3, values = A }, { x = 6, y = 3, values = B } }

return {
    {
        name = "merge two matrices and win through to the recap",
        make_scene = from_def(add_def),
        steps = two_pushers(8, {
            -- B's pusher stops after the merge so only A carries the sum on.
            { drag = { from = { id = "chip:stop" }, to = { slot = { 1, 2 } } } },
            { assert_text = "SRC 1" },
            { assert_text = "SRC 2" },
            { assert_text = "INPUT 2" },
            { assert_tile = { x = 2, y = 3, kind = "source", index = 1 } },
            { assert_tile = { x = 7, y = 4, kind = "source", index = 2 } },
            { assert_tile = { x = 5, y = 3, kind = "op", op = "matrix_add", facing = "right" } },
            { assert_matrices = previews },
            { click_button = "Run" },
            -- Tick 1: both slide in with their own values.
            { wait = 5 },
            { assert_matrices = { { x = 3, y = 3, values = A }, { x = 5, y = 3, values = B } } },
            -- Then only the sum is left, and it travels on to the sink.
            { wait_until = { matrices = { { values = SUM } }, max_frames = 60 } },
            { wait_until = { text = "WIN!", max_frames = 600 } },
            { wait = 30 },
            { assert_matrices = { { x = 5, y = 3, values = SUM } } },
            { click_button = "Continue" },
            { assert_text = "SOLVED!" },
        }),
    },
    {
        name = "shape mismatch shows the sizes; reset restores both previews",
        make_scene = from_def(mul_def),
        steps = two_pushers(9, {
            { click_button = "Run" },
            { wait_until = { text = "FAIL — can't multiply 2x3 by 2x2", max_frames = 120 } },
            { wait = 30 },
            { assert_text = "FAIL — can't multiply 2x3 by 2x2" },
            { assert_matrices = { { x = 3, y = 3, values = WIDE }, { x = 6, y = 3, values = A } } },
            { click_button = "Reset" },
            { assert_no_text = "FAIL — can't multiply 2x3 by 2x2" },
            { assert_matrices = { { x = 2, y = 3, values = WIDE }, { x = 7, y = 3, values = A } } },
        }),
    },
}
