-- Editor op tiles: editing k and direction by thirds, erasing, Copy / Paste,
-- rejection of unsupported definitions, and testing a pasted edge tile.

local function add(steps, ...)
    for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
end

local function repeat_click(steps, x, y, part, n)
    for _ = 1, n do add(steps, { click_cell = { x, y, part = part } }) end
end

local function pick(steps, tool)
    add(steps, { click_button = { id = "editor:pal:" .. tool } })
end

local function expect(steps, x, y, op, scalar, edge)
    add(steps, { assert_tile = { x = x, y = y, kind = "op", op = op, scalar = scalar, edge = edge } })
end

local specs = {}

-- Whole-matrix k tiles ------------------------------------------------------

local whole = {
    -- op, default, min, max, text at max, text at min
    { "scalar_mul", 2, -9, 9, "x9", "x-9" },
    { "scalar_add", 1,  0, 9, "+9", "+0"  },
    { "scalar_sub", 1,  0, 9, "-9", "-0"  },
}
for _, w in ipairs(whole) do
    local op, default, min, max, max_text, min_text = unpack(w)
    local steps = { { click_button = "Editor" } }
    pick(steps, op)
    add(steps, { click_cell = { 4, 4 } })
    expect(steps, 4, 4, op, default)
    add(steps, { click_cell = { 4, 4, part = "centre" } })
    expect(steps, 4, 4, op, default)
    repeat_click(steps, 4, 4, "right", max - default)
    expect(steps, 4, 4, op, max)
    add(steps, { assert_text = max_text }, { click_cell = { 4, 4, part = "right" } })
    expect(steps, 4, 4, op, max)
    repeat_click(steps, 4, 4, "left", max - min)
    expect(steps, 4, 4, op, min)
    add(steps, { assert_text = min_text }, { assert_no_text = max_text },
        { click_cell = { 4, 4, part = "left" } })
    expect(steps, 4, 4, op, min)
    add(steps, { click_cell = { 4, 4, part = "centre" } })
    expect(steps, 4, 4, op, min)
    specs[#specs + 1] = { name = op .. " tile: thirds change k and clamp", given = { solved = {} }, steps = steps }
end

-- Edge tiles ----------------------------------------------------------------

local edges = {
    -- op, default k, text after one right click
    { "edge_scale", 2, "x3" },
    { "edge_add",   1, "+2" },
    { "edge_sub",   1, "-2" },
}
for _, e in ipairs(edges) do
    local op, default, text = unpack(e)
    local steps = { { click_button = "Editor" } }
    pick(steps, op)
    add(steps, { click_cell = { 6, 3 } })
    expect(steps, 6, 3, op, default, "top")
    add(steps, { click_cell = { 6, 3, part = "right" } }, { assert_text = text })
    expect(steps, 6, 3, op, default + 1, "top")
    add(steps, { assert_no_text = ">" }, { click_cell = { 6, 3, part = "centre" } }, { assert_text = ">" })
    expect(steps, 6, 3, op, default + 1, "right")
    add(steps, { click_cell = { 6, 3, part = "centre" } })
    expect(steps, 6, 3, op, default + 1, "bottom")
    add(steps, { click_cell = { 6, 3, part = "centre" } }, { assert_text = "<" })
    expect(steps, 6, 3, op, default + 1, "left")
    add(steps, { click_cell = { 6, 3, part = "centre" } }, { assert_no_text = "<" })
    expect(steps, 6, 3, op, default + 1, "top")
    add(steps, { click_cell = { 6, 3, part = "left" } })
    expect(steps, 6, 3, op, default, "top")
    specs[#specs + 1] = { name = op .. " tile: middle turns clockwise, sides change k", given = { solved = {} }, steps = steps }
end

-- Other tools ---------------------------------------------------------------

do
    local steps = { { click_button = "Editor" } }
    pick(steps, "edge_add")
    add(steps, { click_cell = { 5, 5 } })
    -- every non-eraser tool edits the k tile instead of replacing it
    local k = 1
    for _, tool in ipairs({ "source", "sink", "gap", "pusher", "transpose", "scalar_mul" }) do
        pick(steps, tool)
        add(steps, { click_cell = { 5, 5, part = "right" } })
        k = k + 1
        expect(steps, 5, 5, "edge_add", k, "top")
    end
    specs[#specs + 1] = { name = "clicking a k tile with another tool edits it", given = { solved = {} }, steps = steps }
end

specs[#specs + 1] = {
    name  = "a pasted k tile can be edited with no tool selected",
    given = { solved = {} },
    steps = {
        { click_button  = "Editor" },
        { set_clipboard = [[return {
    locked = { { kind="op", op="edge_sub", x=4, y=6, params={scalar=4, edge="bottom"} } },
    input  = { rows=2, cols=2, values={ {1,2},{3,4} } },
    target = { rows=2, cols=2, values={ {1,2},{3,4} } },
}]] },
        { click_button  = { id = "editor:paste" } },
        { assert_tile   = { x = 4, y = 6, kind = "op", op = "edge_sub", scalar = 4, edge = "bottom" } },
        { click_cell    = { 4, 6, part = "left" } },
        { click_cell    = { 4, 6, part = "centre" } },
        { assert_tile   = { x = 4, y = 6, kind = "op", op = "edge_sub", scalar = 3, edge = "left" } },
        { assert_text   = "-3" },
    },
}

specs[#specs + 1] = {
    name  = "a tile without k is not changed by clicks",
    given = { solved = {} },
    steps = {
        { click_button = "Editor" },
        { click_button = { id = "editor:pal:flip_v" } },
        { click_cell   = { 2, 7 } },
        { click_button = { id = "editor:pal:scalar_add" } },
        { click_cell   = { 2, 7, part = "left" } },
        { click_cell   = { 2, 7, part = "centre" } },
        { click_cell   = { 2, 7, part = "right" } },
        { assert_tile  = { x = 2, y = 7, kind = "op", op = "flip_v" } },
    },
}

-- Erasing -------------------------------------------------------------------

do
    local steps = { { click_button = "Editor" } }
    for _, part in ipairs({ "left", "centre", "right" }) do
        pick(steps, "edge_scale")
        add(steps, { click_cell = { 3, 3 } })
        expect(steps, 3, 3, "edge_scale", 2, "top")
        pick(steps, "erase")
        add(steps, { click_cell = { 3, 3, part = part } }, { assert_tile = { x = 3, y = 3 } })
    end
    pick(steps, "scalar_mul")
    add(steps, { click_cell = { 3, 3 } }, { right_click_cell = { 3, 3 } }, { assert_tile = { x = 3, y = 3 } })
    specs[#specs + 1] = { name = "eraser and right-click remove a k tile", given = { solved = {} }, steps = steps }
end

-- Copy and Paste ------------------------------------------------------------

do
    local steps = { { click_button = "Editor" } }
    pick(steps, "edge_add")
    add(steps, { click_cell = { 5, 2 } })
    repeat_click(steps, 5, 2, "centre", 3)
    repeat_click(steps, 5, 2, "right", 2)
    pick(steps, "scalar_mul")
    add(steps, { click_cell = { 7, 7 } })
    repeat_click(steps, 7, 7, "left", 3)
    -- distinctive matrix values: input (1,1) becomes 7, target (2,2) becomes 5
    local input_cell  = { click_button = { id = "editor:input_cell:1,1" } }
    local target_cell = { click_button = { id = "editor:target_cell:2,2" } }
    for _ = 1, 6 do add(steps, input_cell) end
    for _ = 1, 4 do add(steps, target_cell) end
    add(steps, { assert_text = "7" }, { assert_text = "5" },
        { click_button = { id = "editor:copy" } },
        input_cell, target_cell,
        { assert_text = "8" }, { assert_text = "6" })
    pick(steps, "erase")
    add(steps,
        { click_cell = { 5, 2 } }, { click_cell = { 7, 7 } },
        { assert_tile = { x = 5, y = 2 } }, { assert_tile = { x = 7, y = 7 } },
        { click_button = { id = "editor:paste" } })
    expect(steps, 5, 2, "edge_add", 3, "left")
    expect(steps, 7, 7, "scalar_mul", -1)
    add(steps, { assert_text = "+3" }, { assert_text = "x-1" }, { assert_text = "<" },
        { assert_text = "7" }, { assert_text = "5" },
        { assert_no_text = "8" }, { assert_no_text = "6" }, { assert_no_text = "table:" })
    specs[#specs + 1] = { name = "copy then paste keeps k, direction and matrices", given = { solved = {} }, steps = steps }
end

local rejected = {
    -- name, ops line, bad locked entry, expected message
    { "removed op in locked", "", [[{ kind="op", op="negate", x=3, y=3 },]], "Unsupported op: negate" },
    { "removed op in ops list", [[ops = { "swap_rows" },]], "", "Unsupported op: swap_rows" },
    { "unknown edge", "", [[{ kind="op", op="edge_add", x=3, y=3, params={edge="middle"} },]], "Invalid edge: middle" },
    { "scalar out of range", "", [[{ kind="op", op="scalar_add", x=3, y=3, params={scalar=12} },]],
      "Invalid scalar for scalar_add: 12" },
    { "fractional scalar", "", [[{ kind="op", op="edge_scale", x=3, y=3, params={scalar=1.5} },]],
      "Invalid scalar for edge_scale: 1.5" },
}
for _, r in ipairs(rejected) do
    local name, ops_line, entry, message = unpack(r)
    local clip = string.format([[return {
    name = "Rejected",
    %s
    locked = { { kind="op", op="transpose", x=2, y=2 }, %s },
    input  = { rows=2, cols=2, values={ {5,6},{7,8} } },
    target = { rows=2, cols=2, values={ {5,6},{7,8} } },
}]], ops_line, entry)
    specs[#specs + 1] = {
        name  = "paste rejects " .. name .. " and leaves the editor unchanged",
        given = { solved = {} },
        steps = {
            { click_button   = "Editor" },
            { click_button   = { id = "editor:pal:edge_add" } },
            { click_cell     = { 8, 4 } },
            { set_clipboard  = clip },
            { click_button   = { id = "editor:paste" } },
            { assert_text    = message },
            { assert_tile    = { x = 8, y = 4, kind = "op", op = "edge_add", scalar = 1, edge = "top" } },
            { assert_tile    = { x = 2, y = 2 } },
            { assert_tile    = { x = 3, y = 3 } },
            { assert_no_text = "Rejected" },
            { assert_no_text = "8" },
            { wait           = 150 },
            { assert_no_text = message },
        },
    }
end

-- Test run ------------------------------------------------------------------

do
    -- Default input is the 2x2 identity. The source at (2,2) is pushed right
    -- over a "+1" tile turned to the right edge.
    local steps = { { click_button = "Editor" } }
    pick(steps, "source")
    add(steps, { click_cell = { 2, 2 } })
    pick(steps, "edge_add")
    add(steps, { click_cell = { 5, 2 } }, { click_cell = { 5, 2, part = "centre" } },
        { click_button = { id = "editor:copy" } })
    pick(steps, "erase")
    add(steps, { click_cell = { 5, 2 } }, { assert_tile = { x = 5, y = 2 } },
        { click_button = { id = "editor:paste" } },
        { click_button = { id = "editor:test" } })
    expect(steps, 5, 2, "edge_add", 1, "right")
    add(steps,
        { assert_text   = "+1" },
        { click_button  = { id = "palette:pusher" } },
        { click_cell    = { 1, 2 } },
        { drag          = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
        { click_button  = "Run" },
        { wait_until    = { matrix = { { 1, 1 }, { 0, 2 } }, max_frames = 1000 } },
        { click_button  = { id = "cmd:menu" } },
        { assert_text   = "PUZZLE EDITOR" })
    expect(steps, 5, 2, "edge_add", 1, "right")
    specs[#specs + 1] = { name = "a copied edge tile works after Test", given = { solved = {} }, steps = steps }
end

return specs
