-- Editor Test mode: every way out of the test board (Continue, Enter, Menu, Exit to Menu)
-- returns to the editor with the draft kept, and the solution replay is never opened.
-- Normal play's Menu button still goes to level select.

local S = require("tests/support/shipped")

local function add(steps, ...)
    for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
end

local function place(steps, tool, x, y)
    add(steps, { click_button = { id = "editor:pal:" .. tool } }, { click_cell = { x, y } })
end

-- 2x2 identity at (2,2), sink at (6,2): one pusher at (1,2) going right wins.
local function open_test()
    local steps = { { click_button = "Editor" } }
    place(steps, "source", 2, 2)
    place(steps, "sink", 6, 2)
    place(steps, "pusher", 1, 2)
    add(steps, { click_button = { id = "editor:test" } })
    return steps
end

local function win(steps)
    add(steps,
        { drag         = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { click_button = "Run" },
        { wait_until   = { text = "WIN!", max_frames = 2000 } })
end

local function back_in_editor(steps)
    add(steps,
        { assert_text    = "PUZZLE EDITOR" },
        { assert_no_text = "SOLVED!" },
        { assert_no_text = "SELECT PUZZLE" },
        { assert_tile    = { 2, 2, kind = "source" } },
        { assert_tile    = { 6, 2, kind = "sink" } },
        { assert_tile    = { 1, 2, kind = "pusher" } })
end

local function exit_through_settings(steps)
    add(steps,
        { press        = "escape" },
        { assert_text  = "Settings" },
        { click_button = { id = "settings:exit" } })
end

local specs = {}
local function spec(name, steps)
    specs[#specs + 1] = { name = name, given = { solved = {} }, steps = steps }
end

do
    local steps = open_test()
    win(steps)
    add(steps, { click_button = "Continue" })
    back_in_editor(steps)
    add(steps,
        { click_button   = { id = "editor:test" } },
        { assert_button  = { id = "cmd:run", enabled = true } },
        { assert_no_text = "WIN!" })
    spec("Continue after a test win returns to the editor, and Test opens a fresh board", steps)
end

do
    local steps = open_test()
    win(steps)
    add(steps,
        { wait        = 60 },
        { assert_text = "WIN!" },
        { press       = "return" })
    back_in_editor(steps)
    spec("Enter after a test win returns to the editor", steps)
end

do
    local steps = open_test()
    exit_through_settings(steps)
    back_in_editor(steps)
    spec("Exit to Menu before a test win returns to the editor", steps)
end

do
    local steps = open_test()
    win(steps)
    exit_through_settings(steps)
    back_in_editor(steps)
    spec("Exit to Menu after a test win returns to the editor", steps)
end

do
    local steps = open_test()
    win(steps)
    add(steps, { click_button = { id = "cmd:menu" } })
    back_in_editor(steps)
    spec("Menu after a test win returns to the editor", steps)
end

specs[#specs + 1] = {
    name  = "Menu in normal play returns to level select",
    given = { solved = S.before("basics") },
    steps = S.steps({
        { press        = "return" },                        -- title -> level select
        S.arrows("basics"),
        { click_button = S.row("identity") },
        { assert_text  = "Identity Check" },
        { click_button = { id = "cmd:menu" } },
        { assert_text  = "SELECT PUZZLE" },
    }),
}

return specs
