-- Wins single-source puzzles with real input: palette buttons, cell clicks (the
-- left/right thirds change k, the middle third turns an edge tile), chip drags onto
-- timeline slots and Run. Older solutions are the replay table in
-- docs/archive/design/simplified-ops.md, section 7. The solutions with a tick count
-- are the reference solutions at the top of their puzzle files; those specs also
-- continue to the recap and check the ticks shown there.

local S = require("tests/support/shipped")

local EDGES = { "top", "right", "bottom", "left" }          -- middle-third order
local DEFAULT_K = { scalar_mul = 2, edge_scale = 2, scalar_add = 1, edge_add = 1,
                    scalar_sub = 1, edge_sub = 1 }

local function add(steps, step)
    steps[#steps + 1] = step
end

-- Places a tile from the palette, then edits it by thirds until it matches t.
local function place_tile(steps, t)
    local x, y = t.cell[1], t.cell[2]
    local id = (t.fixed and "palette:fixed:" or "palette:") .. t.op
    add(steps, { click_button = { id = id } })
    add(steps, { click_cell = { x, y } })
    if not t.fixed then
        if t.k then
            local delta = t.k - DEFAULT_K[t.op]
            local part  = delta < 0 and "left" or "right"
            for _ = 1, math.abs(delta) do
                add(steps, { click_cell = { x, y, part = part } })
            end
        end
        if t.edge then
            -- A new tile starts at the top; each middle click turns it once.
            local i = 1
            while EDGES[i] ~= t.edge do
                add(steps, { click_cell = { x, y, part = "centre" } })
                i = i + 1
            end
        end
    end
    add(steps, { assert_tile = { x = x, y = y, kind = "op", op = t.op,
                                 scalar = t.k, edge = t.edge } })
end

-- Pushers go down in letter order. Each command is dragged onto lane 1 of its tick;
-- the previously commanded pusher (if different) gets 'stop' on lane 2 of that tick.
local function program(steps, pushers, commands)
    for _, cell in ipairs(pushers) do
        add(steps, { click_button = { id = "palette:pusher" } })
        add(steps, { click_cell = { cell[1], cell[2] } })
        add(steps, { assert_tile = { x = cell[1], y = cell[2], kind = "pusher" } })
    end
    local prev
    for _, c in ipairs(commands) do
        local who, dir, tick = c[1], c[2], c[3]
        add(steps, { click_button = { id = "psel:" .. who } })
        add(steps, { drag = { from = { id = "chip:" .. dir }, to = { slot = { 1, tick } } } })
        add(steps, { assert_slot = { lane = 1, tick = tick,
                                     pusher = who:byte() - 64, cmd = dir } })
        if prev and prev ~= who then
            add(steps, { click_button = { id = "psel:" .. prev } })
            add(steps, { drag = { from = { id = "chip:stop" }, to = { slot = { 2, tick } } } })
            add(steps, { assert_slot = { lane = 2, tick = tick,
                                         pusher = prev:byte() - 64, cmd = "stop" } })
        end
        prev = who
    end
end

local function solve(s)
    local steps = S.steps({ { press = "return" }, S.arrows(s.world) })
    add(steps, { click_button = S.row(s.puzzle) })
    add(steps, { assert_text = s.name })
    program(steps, s.pushers, s.commands)
    for _, t in ipairs(s.tiles) do place_tile(steps, t) end
    add(steps, { click_button = "Run" })
    add(steps, { wait_until = { text = "WIN!", max_frames = 3000 } })
    if s.ticks then
        add(steps, { click_button = "Continue" })
        add(steps, { assert_text = "SOLVED!" })
        add(steps, { assert_text = "TICKS" })
        add(steps, { assert_text = tostring(s.ticks) })
    end
    return {
        name  = "solve puzzle " .. S.puzzle(s.puzzle) .. " (" .. s.name .. ")",
        given = { solved = "all" },
        steps = steps,
    }
end

-- Routes shared by several puzzles ------------------------------------------

local TURN = {
    pushers  = { { 1, 2 }, { 9, 1 } },
    commands = { { "A", "right", 1 }, { "B", "down", 7 } },
}
local ARCH = {
    pushers  = { { 1, 2 }, { 7, 1 }, { 8, 8 } },
    commands = { { "A", "right", 1 }, { "B", "down", 5 }, { "C", "left", 11 } },
}

local function spec(puzzle, world, name, route, tiles, ticks)
    return solve({ puzzle = puzzle, world = world, name = name, tiles = tiles,
                   pushers = route.pushers, commands = route.commands, ticks = ticks })
end

-- Tile shorthands ------------------------------------------------------------

local function neg(x, y)    return { cell = { x, y }, op = "scalar_mul", k = -1 } end
local function T(x, y)      return { cell = { x, y }, op = "transpose" } end
local function edge(op, k, side, x, y)
    return { cell = { x, y }, op = op, k = k, edge = side }
end
-- A fixed tile comes from its own palette button and keeps the preset k and edge,
-- which are only asserted.
local function fixed(op, x, y, k, side)
    return { cell = { x, y }, op = op, k = k, edge = side, fixed = true }
end

return {
    spec("scale_shift", "basics", "Scale and Shift", {
        pushers  = { { 2, 1 }, { 1, 7 }, { 9, 9 } },
        commands = { { "A", "down", 1 }, { "B", "right", 6 }, { "C", "up", 12 } },
    }, {
        { cell = { 2, 5 }, op = "scalar_mul", k = 3 },
        { cell = { 5, 7 }, op = "scalar_add", k = 4 },
    }, 15),
    spec("set_row", "combos", "Staircase", TURN,
        { edge("edge_scale", 4, "bottom", 5, 2), edge("edge_sub", 8, "right", 7, 2) }),
    spec("corner_case", "combos", "Corner Case", {
        pushers  = { { 1, 3 }, { 8, 1 }, { 10, 7 } },
        commands = { { "A", "right", 1 }, { "B", "down", 6 }, { "C", "left", 10 } },
    }, {
        edge("edge_add", 3, "top", 5, 2),
        edge("edge_scale", 2, "left", 6, 3),
        edge("edge_add", 1, "bottom", 8, 6),
    }, 13),
    spec("top_only", "combos", "Top Only", {
        pushers  = { { 9, 2 }, { 2, 1 }, { 1, 6 } },
        commands = { { "A", "left", 1 }, { "B", "down", 6 }, { "C", "right", 10 } },
    }, {
        fixed("edge_add", 5, 2, 3, "top"),
        fixed("edge_scale", 4, 2, 2, "top"),
        { cell = { 2, 5 }, op = "flip_v" },
        fixed("edge_scale", 5, 7, 2, "top"),
    }, 15),
    spec("fold_through", "combos", "Fold Through", {
        pushers  = { { 1, 2 }, { 8, 1 }, { 10, 8 } },
        commands = { { "A", "right", 1 }, { "B", "down", 7 }, { "C", "left", 12 } },
    }, {
        { cell = { 5, 2 }, op = "scalar_sub", k = 3 },
        edge("edge_scale", -2, "left", 6, 3),
        { cell = { 7, 2 }, op = "scalar_sub", k = 1 },
        T(10, 3),
    }, 16),
    spec("flip_scale", "advanced", "Flip Scale Arch", {
        pushers  = { { 1, 3 }, { 7, 1 }, { 8, 8 } },
        commands = { { "A", "right", 1 }, { "B", "down", 5 }, { "C", "left", 11 } },
    }, { T(7, 5) }),
    spec("locked_scale", "advanced", "Locked Scale, Full Maze", ARCH, { T(7, 4), neg(7, 6) }),
    spec("double_negative", "advanced", "Double Negative", ARCH,
        { edge("edge_scale", -1, "right", 7, 4), edge("edge_scale", -1, "bottom", 7, 6) }),
    spec("add_only", "advanced", "Add Only", {
        pushers  = { { 1, 2 }, { 8, 1 }, { 10, 9 } },
        commands = { { "A", "right", 1 }, { "B", "down", 7 }, { "C", "left", 13 } },
    }, {
        fixed("rotate_90", 4, 2),
        fixed("scalar_mul", 5, 2, -1),
        fixed("edge_add", 6, 2, 3, "top"),
        fixed("scalar_mul", 7, 2, -1),
        fixed("rotate_90", 8, 2),
        fixed("rotate_90", 9, 2),
        fixed("rotate_90", 8, 4),
    }, 17),
}
