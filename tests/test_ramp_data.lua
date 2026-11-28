-- The shipped lineup and its difficulty claim: each world holds its puzzles in ramp
-- order, the cut puzzles are gone, and none of the five redesigned puzzles can be
-- solved with a shorter op chain than designed, whatever the board allows.

local PuzzleLoader = require("lua/game/puzzle_loader")
local Matrix       = require("lua/game/matrix_math")
local Sim          = require("lua/game/pusher_sim")
local Ops          = require("lua/game/ops")
local S            = require("tests/support/shipped")

-- ── Lineup ───────────────────────────────────────────────────────────────────

-- Only relative order is checked, so puzzles and worlds may be inserted anywhere.
local LINEUP = {
    { world = "basics", ids = { "identity", "flip", "scale_shift" } },
    { world = "combos",
      ids = { "rotate_gap", "set_row", "corner_case", "top_only", "fold_through" } },
    { world = "advanced",
      ids = { "flip_scale", "locked_scale", "double_negative", "add_only", "rotato" } },
    { world = "two_sources",
      ids = { "first_sum", "take_away", "turned_sum", "operand_order", "two_preps",
              "merge_maze" } },
}

local last_world = 0
for _, entry in ipairs(LINEUP) do
    local w = S.world(entry.world)
    assert(w > last_world, "world " .. entry.world .. " is out of order")
    last_world = w
    local position = {}
    for i, n in ipairs(PuzzleLoader.world_indices(w)) do position[PuzzleLoader.id(n)] = i end
    local last = 0
    for _, id in ipairs(entry.ids) do
        assert(position[id], id .. " is not in " .. entry.world)
        assert(position[id] > last, id .. " is out of order in " .. entry.world)
        last = position[id]
    end
end
print("PASS: the worlds and their puzzles are in ramp order")

local REMOVED = {
    "swap", "scale", "row_swap", "uturn", "negate_swap", "elimination", "col_ops", "flips",
    "fixed_puzzle", "stand_to_add", "negate", "combo", "double_flip", "triple", "fixed_player",
}
local shipped = {}
for n = 1, PuzzleLoader.count() do shipped[PuzzleLoader.id(n)] = true end
for _, id in ipairs(REMOVED) do assert(not shipped[id], id .. " should not be shipped") end
print("PASS: the removed puzzles are not shipped")

-- ── Shortest op chains ───────────────────────────────────────────────────────

local function matrix(m) return Matrix.new(m.rows, m.cols, m.values) end

-- Every tile the puzzle's palette can produce: each offered op with every legal k
-- and edge, and each fixed op with its preset params.
local function palette(def)
    local tiles = {}
    local function add(op, params)
        assert(Ops.is_op(op) and not Ops.is_two_cell(op), "unsearchable op " .. tostring(op))
        tiles[#tiles + 1] = { kind = "op", op = op, params = params }
    end
    assert(type(def.ops) == "table", def.name .. " lists its ops")
    for _, op in ipairs(def.ops) do
        local min, max = Ops.range(op)
        for _, edge in ipairs(Ops.has_edge(op) and Ops.EDGES or { false }) do
            for k = min or 0, max or 0 do
                add(op, { edge = edge or nil, scalar = min and k or nil })
            end
        end
    end
    for _, f in ipairs(def.fixed_ops or {}) do
        if type(f) == "table" then add(f.op, f.params) else add(f) end
    end
    return tiles
end

local function key(m)
    local parts = { m.rows, m.cols }
    for r = 1, m.rows do
        for c = 1, m.cols do parts[#parts + 1] = m.values[r][c] end
    end
    return table.concat(parts, ",")
end

-- Length of the shortest chain of at most `limit` tiles that turns the input into
-- the target, or nil. Breadth first; the last level is compared but not stored.
local function shortest(def, limit)
    local tiles  = palette(def)
    local input  = matrix(def.input)
    local target = matrix(def.target)
    if input:equals(target) then return 0 end
    local seen, frontier = { [key(input)] = true }, { input }
    for length = 1, limit do
        local reached = {}
        for _, m in ipairs(frontier) do
            for _, tile in ipairs(tiles) do
                local result = Sim.apply_op(tile, m)
                if result:equals(target) then return length end
                if length < limit then
                    local k = key(result)
                    if not seen[k] then
                        seen[k] = true
                        reached[#reached + 1] = result
                    end
                end
            end
        end
        frontier = reached
    end
    return nil
end

-- `exact` also searches the designed length, proving the search does find the
-- target there. That is too slow for Corner Case and Fold Through, whose chains
-- test_multi_op_puzzles.lua runs.
local function check_minimum(id, minimum, exact)
    local def = PuzzleLoader.load(S.puzzle(id))
    local found = shortest(def, exact and minimum or minimum - 1)
    local expected = nil
    if exact then expected = minimum end
    assert(found == expected, string.format("%s: shortest chain is %s, designed %d",
        id, tostring(found or ("at least " .. minimum)), minimum))
    print("PASS: " .. id .. " needs " .. minimum .. " ops")
end

check_minimum("scale_shift",  2, true)
check_minimum("corner_case",  3, false)
check_minimum("top_only",     4, true)
check_minimum("fold_through", 4, false)
check_minimum("add_only",     7, true)

do
    local def = PuzzleLoader.load(S.puzzle("scale_shift"))
    local input, target = matrix(def.input), matrix(def.target)
    local add_min, add_max = Ops.range("scalar_add")
    local mul_min, mul_max = Ops.range("scalar_mul")
    for a = add_min, add_max do
        for m = mul_min, mul_max do
            assert(not input:scalar_add(a):scalar_mul(m):equals(target),
                string.format("scale_shift: +%d then x%d reaches the target", a, m))
        end
    end
    print("PASS: Scale and Shift cannot add before multiplying")
end

print("ALL RAMP DATA TESTS PASSED")
