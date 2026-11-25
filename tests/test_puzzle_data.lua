-- test_puzzle_data.lua
-- Every shipped puzzle uses only supported ops and params, locked op tiles are
-- 1x1, and the five worlds cover the expected puzzle ranges.

local PuzzleLoader = require("lua/game/puzzle_loader")
local Ops          = require("lua/game/ops")

local function check_op(where, op, params)
    local ok, message = Ops.validate(op, params)
    assert(ok, string.format("%s: %s", where, tostring(message)))
end

-- ── Ops, fixed ops and locked tiles ──────────────────────────────────────────

for n = 1, PuzzleLoader.count() do
    local def = PuzzleLoader.load(n)

    for i, op in ipairs(def.ops or {}) do
        check_op(string.format("puzzle %d ops[%d]", n, i), op)
    end

    local seen = {}
    for i, entry in ipairs(def.fixed_ops or {}) do
        local op, params = entry, nil
        if type(entry) == "table" then op, params = entry.op, entry.params end
        check_op(string.format("puzzle %d fixed_ops[%d]", n, i), op, params)
        assert(not seen[op], string.format("puzzle %d lists fixed op %s twice", n, op))
        seen[op] = true
    end

    for i, tile in ipairs(def.locked or {}) do
        local where = string.format("puzzle %d locked[%d]", n, i)
        if tile.kind == "op" then
            check_op(where, tile.op, tile.params)
        end
        for _, field in ipairs({ "width", "height", "tile_rows", "tile_cols" }) do
            assert(tile[field] == nil, where .. " must not set " .. field)
        end
    end
end
print("PASS: every shipped puzzle uses supported ops and params")

-- ── World ranges ─────────────────────────────────────────────────────────────

local expected = {
    { name = "Basics",       first = 1,  last = 5  },
    { name = "Combos",       first = 6,  last = 11 },
    { name = "Advanced",     first = 12, last = 15 },
    { name = "Transforms",   first = 16, last = 18 },
    { name = "Fixed Pieces", first = 19, last = 21 },
}

assert(PuzzleLoader.world_count() == #expected, "expected five worlds")
for w, want in ipairs(expected) do
    local world = PuzzleLoader.world(w)
    assert(world.name == want.name, string.format("world %d is named %s", w, want.name))
    assert(#world.puzzles == want.last - want.first + 1,
        string.format("world %d has %d puzzles", w, want.last - want.first + 1))
    for i, p in ipairs(world.puzzles) do
        assert(p.index == want.first + i - 1,
            string.format("world %d entry %d is puzzle %d", w, i, want.first + i - 1))
    end
end
assert(PuzzleLoader.count() == expected[#expected].last, "no puzzle lies outside the worlds")
print("PASS: world ranges")

print("ALL PUZZLE DATA TESTS PASSED")
