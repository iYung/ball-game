-- Op tiles in the puzzle scene, driven through real input:
--   1. placing each k tile; left/right thirds change k and clamp, middle does
--      nothing on a whole-matrix tile
--   2. the middle third turns an edge tile clockwise and keeps k
--   3. a turned edge tile changes exactly that edge during a run
--   4. fixed (Add Only) and locked (Locked Scale) tiles cannot be edited
--   5. Mv keeps k and edge; the eraser removes a tile from any third
--
-- Puzzle 1 has no `ops` restriction, so every op button is shown.
-- Edge direction is asserted on tile state and on run results: the timeline
-- chips always draw the same arrow characters, so the arrow text proves nothing here.

local S = require("tests/support/shipped")

local function add(steps, ...)
    for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
end

local function open_puzzle_1()
    return S.steps({
        { press = "return" },
        S.arrows("basics"),
        { click_button = S.row("identity") },
        { assert_text = "Identity Check" },
    })
end

-- The Advanced world, reached with the world keys.
local function open_advanced(id, name)
    return S.steps({
        { press = "return" },
        S.arrows("advanced"),
        { assert_button = { id = S.tab("advanced").id, selected = true } },
        { click_button = S.row(id) },
        { assert_text = name },
    })
end

local function pick(steps, tool)
    add(steps, { click_button = { id = "palette:" .. tool } })
end

local function click(steps, x, y, part, n)
    for _ = 1, n or 1 do add(steps, { click_cell = { x, y, part = part } }) end
end

local function expect(steps, x, y, op, scalar, edge)
    add(steps, { assert_tile = { x = x, y = y, kind = "op", op = op, scalar = scalar, edge = edge } })
end

local function empty(steps, x, y)
    add(steps, { assert_tile = { x = x, y = y } })
end

local specs = {}
local function spec(name, steps, given)
    specs[#specs + 1] = { name = name, given = given or { solved = S.before("basics") }, steps = steps }
end

-- 1. Every k tile: thirds change k and clamp ---------------------------------

local k_ops = {
    -- op, default, min, max, text at default, text at max, text at min, edge
    { "scalar_mul", 2, -9, 9, "x2", "x9", "x-9" },
    { "edge_scale", 2, -9, 9, "x2", "x9", "x-9", "top" },
    { "scalar_add", 1,  0, 9, "+1", "+9", "+0"  },
    { "edge_add",   1,  0, 9, "+1", "+9", "+0",  "top" },
    { "scalar_sub", 1,  0, 9, "-1", "-9", "-0"  },
    { "edge_sub",   1,  0, 9, "-1", "-9", "-0",  "top" },
}
for _, o in ipairs(k_ops) do
    local op, default, min, max, default_text, max_text, min_text, edge = unpack(o)
    local steps = open_puzzle_1()
    add(steps, { assert_no_text = default_text })
    pick(steps, op)
    click(steps, 5, 2)
    expect(steps, 5, 2, op, default, edge)
    add(steps, { assert_text = default_text })
    if not edge then
        -- Middle of a whole-matrix tile: nothing changes.
        click(steps, 5, 2, "centre")
        expect(steps, 5, 2, op, default)
        add(steps, { assert_text = default_text })
    end

    click(steps, 5, 2, "right")
    expect(steps, 5, 2, op, default + 1, edge)
    click(steps, 5, 2, "left")
    expect(steps, 5, 2, op, default, edge)

    click(steps, 5, 2, "right", max - default)
    expect(steps, 5, 2, op, max, edge)
    add(steps, { assert_text = max_text })
    click(steps, 5, 2, "right")
    expect(steps, 5, 2, op, max, edge)
    add(steps, { assert_text = max_text })

    click(steps, 5, 2, "left", max - min)
    expect(steps, 5, 2, op, min, edge)
    add(steps, { assert_text = min_text }, { assert_no_text = max_text })
    click(steps, 5, 2, "left")
    expect(steps, 5, 2, op, min, edge)
    add(steps, { assert_text = min_text })

    if not edge then
        click(steps, 5, 2, "centre")
        expect(steps, 5, 2, op, min)
    end

    -- Another palette tool edits the placed tile instead of replacing it.
    pick(steps, "transpose")
    click(steps, 5, 2, "right")
    expect(steps, 5, 2, op, min + 1, edge)
    pick(steps, "pusher")
    click(steps, 5, 2, "left")
    expect(steps, 5, 2, op, min, edge)

    spec(op .. " tile: sides change k and clamp at both limits", steps)
end

-- 2. Middle third turns an edge tile -----------------------------------------

local edge_ops = {
    -- op, k after two right clicks, its text
    { "edge_scale", 4, "x4" },
    { "edge_add",   3, "+3" },
    { "edge_sub",   3, "-3" },
}
for _, e in ipairs(edge_ops) do
    local op, k, text = unpack(e)
    local steps = open_puzzle_1()
    pick(steps, op)
    click(steps, 6, 3)
    click(steps, 6, 3, "right", 2)
    expect(steps, 6, 3, op, k, "top")
    for _, edge in ipairs({ "right", "bottom", "left", "top", "right" }) do
        click(steps, 6, 3, "centre")
        expect(steps, 6, 3, op, k, edge)
        add(steps, { assert_text = text })
    end
    -- Changing k keeps the direction.
    click(steps, 6, 3, "left")
    expect(steps, 6, 3, op, k - 1, "right")
    spec(op .. " tile: middle turns top, right, bottom, left, top and keeps k", steps)
end

-- 3. A turned edge tile changes exactly that edge during a run ----------------

-- Puzzle 1: the pusher at (1,5) carries the identity right; the tile at (5,5)
-- fires once on the way. The result no longer matches the target.
local runs = {
    -- op, centre clicks, edge, left clicks on k, k, result
    { "edge_add",   0, "top",    0,  1, { { 2, 1 }, { 0, 1 } } },
    { "edge_add",   1, "right",  0,  1, { { 1, 1 }, { 0, 2 } } },
    { "edge_add",   2, "bottom", 0,  1, { { 1, 0 }, { 1, 2 } } },
    { "edge_add",   3, "left",   0,  1, { { 2, 0 }, { 1, 1 } } },
    { "edge_sub",   3, "left",   0,  1, { { 0, 0 }, { -1, 1 } } },
    { "edge_scale", 1, "right",  3, -1, { { 1, 0 }, { 0, -1 } } },
}
for _, r in ipairs(runs) do
    local op, turns, edge, lefts, k, result = unpack(r)
    local steps = open_puzzle_1()
    pick(steps, "pusher")
    click(steps, 1, 5)
    add(steps, { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } })
    pick(steps, op)
    click(steps, 5, 5)
    click(steps, 5, 5, "centre", turns)
    click(steps, 5, 5, "left", lefts)
    expect(steps, 5, 5, op, k, edge)
    add(steps,
        { assert_matrix = { { 1, 0 }, { 0, 1 } } },
        { click_button = "Run" },
        { wait_until = { text = "FAIL", max_frames = 3000 } },
        { wait_until = { matrix = result, max_frames = 600 } },
        { assert_matrix = result })
    spec(op .. " turned " .. edge .. " changes only that edge in a run", steps)
end

-- 4. Fixed and locked tiles ---------------------------------------------------

do
    local steps = open_advanced("add_only", "Add Only")
    -- Each fixed tool, the cell it is tested on and its preset.
    local fixed = {
        { tool = "fixed:scalar_mul", x = 5, op = "scalar_mul", scalar = -1 },
        { tool = "fixed:rotate_90",  x = 7, op = "rotate_90" },
        { tool = "fixed:edge_add",   x = 9, op = "edge_add",   scalar = 3, edge = "top" },
    }
    local function expect_preset(f)
        expect(steps, f.x, 2, f.op, f.scalar, f.edge)
    end
    for _, f in ipairs(fixed) do
        pick(steps, f.tool)
        click(steps, f.x, 2)
    end
    for _, f in ipairs(fixed) do expect_preset(f) end
    add(steps, { assert_text = "x-1" }, { assert_text = "+3" })

    -- With each non-eraser tool, no third edits, turns or replaces any tile.
    for _, tool in ipairs({ "fixed:rotate_90", "fixed:edge_add", "fixed:scalar_mul", "pusher", "drag" }) do
        pick(steps, tool)
        for _, part in ipairs({ "left", "centre", "right" }) do
            for _, f in ipairs(fixed) do
                click(steps, f.x, 2, part)
                expect_preset(f)
                add(steps, { assert_no_text = "x-2" }, { assert_no_text = "x0" },
                    { assert_no_text = "+2" }, { assert_no_text = "+4" })
            end
        end
    end

    -- The eraser removes an unlocked fixed tile from any third.
    for _, part in ipairs({ "left", "centre", "right" }) do
        for _, f in ipairs(fixed) do
            pick(steps, f.tool)
            click(steps, f.x, 2)    -- places it, or clicks the tile already there
            expect_preset(f)
            pick(steps, "erase")
            click(steps, f.x, 2, part)
            empty(steps, f.x, 2)
        end
    end
    spec("fixed tiles ignore all three thirds; the eraser removes them", steps, { solved = "all" })
end

do
    local steps = open_advanced("locked_scale", "Locked Scale, Full Maze")
    expect(steps, 5, 3, "edge_scale", 3, "top")
    add(steps, { assert_text = "x3" })
    for _, tool in ipairs({ "scalar_mul", "transpose", "pusher", "drag", "erase" }) do
        pick(steps, tool)
        for _, part in ipairs({ "left", "centre", "right" }) do
            click(steps, 5, 3, part)
            expect(steps, 5, 3, "edge_scale", 3, "top")
            add(steps, { assert_text = "x3" }, { assert_no_text = "x2" }, { assert_no_text = "x4" })
        end
    end
    spec("the locked tile ignores all three thirds, with every tool", steps, { solved = "all" })
end

-- 5. Mv and the eraser --------------------------------------------------------

do
    local steps = open_puzzle_1()
    pick(steps, "edge_add")
    click(steps, 5, 2)
    click(steps, 5, 2, "right", 2)
    click(steps, 5, 2, "centre", 2)
    expect(steps, 5, 2, "edge_add", 3, "bottom")
    pick(steps, "scalar_mul")
    click(steps, 8, 2)
    click(steps, 8, 2, "left", 5)
    expect(steps, 8, 2, "scalar_mul", -3)

    pick(steps, "drag")
    add(steps, { drag = { from = { cell = { 5, 2 } }, to = { cell = { 6, 4 } } } })
    empty(steps, 5, 2)
    expect(steps, 6, 4, "edge_add", 3, "bottom")
    add(steps, { assert_text = "+3" },
        { drag = { from = { cell = { 8, 2 } }, to = { cell = { 9, 4 } } } })
    empty(steps, 8, 2)
    expect(steps, 9, 4, "scalar_mul", -3)
    add(steps, { assert_text = "x-3" })

    -- A click with Mv picks the tile up and puts it back unchanged.
    for _, part in ipairs({ "left", "centre", "right" }) do
        click(steps, 6, 4, part)
        expect(steps, 6, 4, "edge_add", 3, "bottom")
    end

    -- The moved tile is still editable.
    pick(steps, "pusher")
    click(steps, 6, 4, "centre")
    expect(steps, 6, 4, "edge_add", 3, "left")

    pick(steps, "erase")
    click(steps, 6, 4, "centre")
    empty(steps, 6, 4)
    add(steps, { assert_no_text = "+3" })
    click(steps, 9, 4, "centre")
    empty(steps, 9, 4)
    add(steps, { assert_no_text = "x-3" })
    spec("Mv keeps k and edge; the eraser removes a tile from the middle third", steps)
end

return specs
