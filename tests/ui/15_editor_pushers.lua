-- Pushers placed in the editor: Test must give each one a letter so it can be programmed,
-- through Copy / Paste and for pasted definitions with missing, repeated or extra ids.

local function add(steps, ...)
    for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
end

local function place(steps, tool, x, y)
    add(steps, { click_button = { id = "editor:pal:" .. tool } }, { click_cell = { x, y } })
end

-- 2x2 identity at (2,2), sink at (6,2): one pusher at (1,2) going right wins.
local function board(steps)
    place(steps, "source", 2, 2)
    place(steps, "sink", 6, 2)
end

local function letters(steps, present, absent)
    for _, l in ipairs(present) do add(steps, { assert_button = { id = "psel:" .. l } }) end
    for _, l in ipairs(absent) do
        add(steps, { assert_button = { id = "psel:" .. l, visible = false } })
    end
end

local function win_with_a(steps)
    add(steps,
        { click_button = { id = "psel:A" } },
        { drag         = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { assert_slot  = { lane = 1, tick = 1, pusher = 1, cmd = "right" } },
        { click_button = "Run" },
        { wait_until   = { text = "WIN!", max_frames = 2000 } })
end

local function definition(pushers)
    local entries = {}
    for _, p in ipairs(pushers) do
        local id = p.id and (", id=" .. p.id) or ""
        entries[#entries + 1] = string.format('{ kind="pusher", x=%d, y=%d%s }', p[1], p[2], id)
    end
    return 'return { name="Pasted", grid_w=10, grid_h=10, source={x=2,y=2}, sink={x=6,y=2},'
        .. ' input={rows=2,cols=2,values={{1,0},{0,1}}},'
        .. ' target={rows=2,cols=2,values={{1,0},{0,1}}},'
        .. ' locked={' .. table.concat(entries, ",") .. '} }'
end

local specs = {}
local function spec(name, steps)
    specs[#specs + 1] = { name = name, given = { solved = {} }, steps = steps }
end

do
    local steps = { { click_button = "Editor" } }
    board(steps)
    place(steps, "pusher", 1, 2)
    add(steps, { click_button = { id = "editor:test" } })
    letters(steps, { "A" }, { "B" })
    win_with_a(steps)
    spec("one editor pusher can be programmed in Test", steps)
end

do
    local steps = { { click_button = "Editor" } }
    board(steps)
    place(steps, "pusher", 1, 2)
    place(steps, "pusher", 1, 6)
    add(steps, { click_button = { id = "editor:test" } })
    letters(steps, { "A", "B" }, { "C" })
    -- The first pusher is selected without any click, so a chip can be dragged straight away.
    add(steps, { assert_button = { id = "psel:A", selected = true } },
        { drag        = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { assert_slot = { lane = 1, tick = 1, pusher = 1, cmd = "right" } },
        { click_button = "Run" },
        { wait_until  = { text = "WIN!", max_frames = 2000 } })
    spec("two editor pushers get letters A and B in Test", steps)
end

do
    local steps = { { click_button = "Editor" } }
    board(steps)
    place(steps, "pusher", 1, 6)
    place(steps, "pusher", 1, 2)
    place(steps, "erase", 1, 6)
    place(steps, "pusher", 1, 8)
    add(steps, { click_button = { id = "editor:test" } })
    -- (1,2) kept B; the new pusher reused the freed letter A.
    letters(steps, { "A", "B" }, { "C" })
    add(steps,
        { click_button = { id = "psel:B" } },
        { drag         = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { click_button = "Run" },
        { wait_until   = { text = "WIN!", max_frames = 2000 } })
    spec("an erased pusher frees its letter", steps)
end

do
    local steps = { { click_button = "Editor" } }
    board(steps)
    place(steps, "pusher", 1, 6)
    place(steps, "pusher", 1, 2)
    place(steps, "erase", 1, 6)
    add(steps, { click_button = { id = "editor:copy" } })
    place(steps, "erase", 1, 2)
    add(steps, { click_button = { id = "editor:paste" } },
        { click_button = { id = "editor:test" } })
    letters(steps, { "B" }, { "A", "C" })
    spec("Copy and Paste keep pusher letters", steps)
end

do
    local steps = { { click_button = "Editor" } }
    board(steps)
    for x = 1, 9 do place(steps, "pusher", x, 8) end
    add(steps, { assert_tile = { x = 8, y = 8, kind = "pusher" } },
        { assert_tile = { x = 9, y = 8 } },
        { click_button = { id = "editor:test" } })
    letters(steps, { "A", "H" }, { "I" })
    spec("the editor places at most eight pushers", steps)
end

do
    local steps = {
        { click_button = "Editor" },
        { set_clipboard = definition({ { 1, 2 }, { 1, 6 } }) },
        { click_button = { id = "editor:paste" } },
        { click_button = { id = "editor:test" } },
    }
    letters(steps, { "A", "B" }, { "C" })
    win_with_a(steps)
    spec("a pasted definition without pusher ids gets letters", steps)
end

do
    -- The explicit B is kept; the repeat, the out-of-range id and the missing id fill A, C, D.
    local steps = {
        { click_button = "Editor" },
        { set_clipboard = definition({ { 1, 4 }, { 1, 2, id = 2 }, { 1, 6, id = 2 },
                                       { 1, 8, id = 99 } }) },
        { click_button = { id = "editor:paste" } },
        { click_button = { id = "editor:test" } },
    }
    letters(steps, { "A", "B", "C", "D" }, { "E" })
    add(steps,
        { click_button = { id = "psel:B" } },
        { drag         = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { click_button = "Run" },
        { wait_until   = { text = "WIN!", max_frames = 2000 } })
    spec("repeated and invalid pasted ids are reassigned", steps)
end

do
    local pushers = {}
    for x = 1, 10 do pushers[#pushers + 1] = { x, 8 } end
    local steps = {
        { click_button = "Editor" },
        { set_clipboard = definition(pushers) },
        { click_button = { id = "editor:paste" } },
        { assert_tile = { x = 8, y = 8, kind = "pusher" } },
        { assert_tile = { x = 9, y = 8 } },
        { assert_tile = { x = 10, y = 8 } },
        { click_button = { id = "editor:test" } },
    }
    letters(steps, { "A", "H" }, { "I" })
    spec("extra pasted pushers are dropped", steps)
end

return specs
