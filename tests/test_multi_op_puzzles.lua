-- Reference solutions of the converted puzzles: the shipped puzzle data, run through
-- the op chain from docs/archive/design/simplified-ops.md (section 7), must reach the target.

local S = require("tests/support/shipped")
local Matrix       = require("lua/game/matrix_math")
local Sim          = require("lua/game/pusher_sim")
local PuzzleLoader = require("lua/game/puzzle_loader")

-- Chain entries -------------------------------------------------------------

-- A tile the player places from the puzzle's palette.
local function player(op, params)
    return { source = "player", op = op, params = params }
end
-- The locked tile at (x, y), taken from the puzzle file.
local function locked(x, y)
    return { source = "locked", x = x, y = y }
end
-- The fixed_ops entry for op, taken from the puzzle file.
local function fixed(op)
    return { source = "fixed", op = op }
end

local function neg() return player("scalar_mul", { scalar = -1 }) end
local function edge(op, side, k) return player(op, { edge = side, scalar = k }) end

local function resolve(n, puzzle, entry)
    if entry.source == "player" then
        local offered = puzzle.ops == nil
        for _, op in ipairs(puzzle.ops or {}) do
            if op == entry.op then offered = true end
        end
        assert(offered, "puzzle " .. n .. " does not offer " .. entry.op)
        return { kind = "op", op = entry.op, params = entry.params }
    elseif entry.source == "locked" then
        for _, t in ipairs(puzzle.locked or {}) do
            if t.x == entry.x and t.y == entry.y then return t end
        end
        error("puzzle " .. n .. " has no locked tile at " .. entry.x .. "," .. entry.y)
    end
    for _, f in ipairs(puzzle.fixed_ops or {}) do
        local op, params = f, nil
        if type(f) == "table" then op, params = f.op, f.params end
        if op == entry.op then return { kind = "op", op = op, params = params } end
    end
    error("puzzle " .. n .. " has no fixed op " .. entry.op)
end

local function matrix(m)
    return Matrix.new(m.rows, m.cols, m.values)
end

-- Applies the chain to the puzzle's input and checks it reaches the target. With two
-- or more tiles, no single one of them may be enough on its own.
local function check(id, name, chain)
    local n      = S.puzzle(id)
    local puzzle = PuzzleLoader.load(n)
    assert(puzzle.name == name,
        "puzzle " .. n .. " is '" .. tostring(puzzle.name) .. "', expected '" .. name .. "'")
    local input, target = matrix(puzzle.input), matrix(puzzle.target)
    local result = input
    for _, entry in ipairs(chain) do
        local tile = resolve(n, puzzle, entry)
        if #chain > 1 then
            assert(not Sim.apply_op(tile, input):equals(target),
                "puzzle " .. n .. ": " .. tile.op .. " alone should be insufficient")
        end
        result = Sim.apply_op(tile, result)
    end
    assert(result:equals(target), "puzzle " .. n .. " (" .. name .. "): chain misses the target")
    print("PASS: puzzle " .. n .. " - " .. name)
end

check("negate",          "Sharp Left",   { neg() })
check("swap",            "Drop First",   { player("flip_v") })
check("row_swap",        "Z-Bend",       { neg(), player("flip_v") })
-- Both orders work, scaling whichever edge holds the first input row at that moment.
check("double_flip",     "Ordered Ops",  { edge("edge_scale", "top", 2), player("flip_v") })
check("double_flip",     "Ordered Ops",  { player("flip_v"), edge("edge_scale", "bottom", 2) })
check("combo",           "Corner Scale", { edge("edge_scale", "top", -1) })
check("combo",           "Corner Scale", { edge("edge_scale", "left", -1) })
check("uturn",           "Arch",         { neg(), player("flip_v") })
check("set_row",         "Staircase",    { edge("edge_scale", "bottom", 4), edge("edge_sub", "right", 8) })
check("negate_swap",     "Deep Arch",    { neg(), player("flip_v") })
check("flip_scale",      "Flip Scale Arch", { locked(5, 3), player("transpose") })
check("elimination",     "Three-Step Elimination",
    { edge("edge_scale", "top", 4), edge("edge_sub", "left", 4) })
check("triple",          "Triple Bend",
    { neg(), edge("edge_scale", "top", 2), player("transpose") })
check("col_ops",         "Column Work Maze", { player("flip_h"), edge("edge_scale", "right", 2) })
check("double_negative", "Double Negative",
    { locked(5, 3), edge("edge_scale", "right", -1), edge("edge_scale", "bottom", -1) })
check("fixed_player",    "Fixed Tools, Bent Path", { fixed("scalar_mul"), fixed("flip_v") })
check("fixed_puzzle",    "Mandatory Negate, Arch Path", { locked(6, 6) })
check("locked_scale",    "Locked Scale, Full Maze", { locked(5, 3), player("transpose"), neg() })
