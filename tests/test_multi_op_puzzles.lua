-- Reference solutions of the single-source puzzles: the shipped puzzle data, run through
-- the op chain of its solution, must reach the target.

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

check("scale_shift",     "Scale and Shift",
    { player("scalar_mul", { scalar = 3 }), player("scalar_add", { scalar = 4 }) })
check("set_row",         "Staircase",    { edge("edge_scale", "bottom", 4), edge("edge_sub", "right", 8) })
check("corner_case",     "Corner Case",
    { edge("edge_add", "top", 3), edge("edge_scale", "left", 2), edge("edge_add", "bottom", 1) })
check("top_only",        "Top Only",
    { fixed("edge_add"), fixed("edge_scale"), player("flip_v"), fixed("edge_scale") })
check("fold_through",    "Fold Through",
    { player("scalar_sub", { scalar = 3 }), edge("edge_scale", "left", -2),
      player("scalar_sub", { scalar = 1 }), player("transpose") })
check("flip_scale",      "Flip Scale Arch", { locked(5, 3), player("transpose") })
check("locked_scale",    "Locked Scale, Full Maze", { locked(5, 3), player("transpose"), neg() })
check("double_negative", "Double Negative",
    { locked(5, 3), edge("edge_scale", "right", -1), edge("edge_scale", "bottom", -1) })
check("add_only",        "Add Only",
    { fixed("rotate_90"), fixed("scalar_mul"), fixed("edge_add"), fixed("scalar_mul"),
      fixed("rotate_90"), fixed("rotate_90"), fixed("rotate_90") })
