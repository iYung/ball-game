-- Wins every converted puzzle with real input: palette buttons, cell clicks (the
-- left/right thirds change k, the middle third turns an edge tile), chip drags onto
-- timeline slots and Run. Solutions are the replay table in
-- docs/archive/design/simplified-ops.md, section 7.

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
    return {
        name  = "solve puzzle " .. S.puzzle(s.puzzle) .. " (" .. s.name .. ")",
        given = { solved = "all" },
        steps = steps,
    }
end

-- Routes shared by several puzzles ------------------------------------------

local Z = {
    pushers  = { { 1, 2 }, { 7, 1 }, { 8, 6 }, { 5, 5 }, { 3, 9 } },
    commands = { { "A", "right", 1 }, { "B", "down", 5 }, { "C", "left", 9 },
                 { "D", "down", 11 }, { "E", "right", 14 } },
}
local TURN = {
    pushers  = { { 1, 2 }, { 9, 1 } },
    commands = { { "A", "right", 1 }, { "B", "down", 7 } },
}
local DEEP = {
    pushers  = { { 1, 3 }, { 9, 1 }, { 10, 8 } },
    commands = { { "A", "right", 1 }, { "B", "down", 7 }, { "C", "left", 13 } },
}
local ARCH = {
    pushers  = { { 1, 2 }, { 7, 1 }, { 8, 8 } },
    commands = { { "A", "right", 1 }, { "B", "down", 5 }, { "C", "left", 11 } },
}

local function spec(puzzle, world, name, route, tiles)
    return solve({ puzzle = puzzle, world = world, name = name, tiles = tiles,
                   pushers = route.pushers, commands = route.commands })
end

-- Tile shorthands ------------------------------------------------------------

local function neg(x, y)    return { cell = { x, y }, op = "scalar_mul", k = -1 } end
local function flip_v(x, y) return { cell = { x, y }, op = "flip_v" } end
local function T(x, y)      return { cell = { x, y }, op = "transpose" } end
local function edge(op, k, side, x, y)
    return { cell = { x, y }, op = op, k = k, edge = side }
end

return {
    spec("negate", "basics", "Sharp Left", TURN, { neg(5, 2) }),
    spec("swap", "basics", "Drop First", {
        pushers  = { { 2, 1 }, { 1, 6 } },
        commands = { { "A", "down", 1 }, { "B", "right", 5 } },
    }, { flip_v(3, 6) }),
    spec("row_swap", "combos", "Z-Bend", Z, { neg(5, 2), flip_v(6, 5) }),
    spec("double_flip", "combos", "Ordered Ops", Z, { edge("edge_scale", 2, "top", 5, 2), flip_v(6, 5) }),
    spec("combo", "combos", "Corner Scale", {
        pushers  = { { 1, 2 }, { 7, 1 } },
        commands = { { "A", "right", 1 }, { "B", "down", 5 } },
    }, { edge("edge_scale", -1, "top", 6, 2) }),
    spec("uturn", "combos", "Arch", DEEP, { neg(5, 2), flip_v(9, 5) }),
    spec("set_row", "combos", "Staircase", TURN,
        { edge("edge_scale", 4, "bottom", 5, 2), edge("edge_sub", 8, "right", 7, 2) }),
    spec("negate_swap", "advanced", "Deep Arch", DEEP, { neg(5, 2), flip_v(9, 5) }),
    spec("flip_scale", "advanced", "Flip Scale Arch", {
        pushers  = { { 1, 3 }, { 7, 1 }, { 8, 8 } },
        commands = { { "A", "right", 1 }, { "B", "down", 5 }, { "C", "left", 11 } },
    }, { T(7, 5) }),
    spec("elimination", "advanced", "Three-Step Elimination", TURN,
        { edge("edge_scale", 4, "top", 5, 2), edge("edge_sub", 4, "left", 7, 2) }),
    spec("triple", "advanced", "Triple Bend", {
        pushers  = { { 1, 2 }, { 5, 1 }, { 6, 5 }, { 2, 9 } },
        commands = { { "A", "right", 1 }, { "B", "down", 3 }, { "C", "left", 6 },
                     { "B", "left", 7 }, { "B", "down", 8 }, { "D", "right", 12 } },
    }, { neg(4, 2), edge("edge_scale", 2, "top", 5, 3), T(3, 7) }),
    spec("col_ops", "transforms", "Column Work Maze", TURN,
        { { cell = { 5, 2 }, op = "flip_h" }, edge("edge_scale", 2, "right", 7, 2) }),
    spec("double_negative", "transforms", "Double Negative", ARCH,
        { edge("edge_scale", -1, "right", 7, 4), edge("edge_scale", -1, "bottom", 7, 6) }),
    -- Fixed tiles come from their own palette buttons and keep the preset k.
    spec("fixed_player", "fixed_pieces", "Fixed Tools, Bent Path", TURN, {
        { cell = { 5, 2 }, op = "scalar_mul", k = -1, fixed = true },
        { cell = { 7, 2 }, op = "flip_v", fixed = true },
    }),
    spec("fixed_puzzle", "fixed_pieces", "Mandatory Negate, Arch Path", ARCH, {}),
    spec("locked_scale", "fixed_pieces", "Locked Scale, Full Maze", ARCH, { T(7, 4), neg(7, 6) }),
}
