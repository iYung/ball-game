-- test_puzzle_data.lua
-- Every shipped puzzle uses only supported ops and params, locked op tiles are
-- 1x1, and the worlds are well formed and list every puzzle once, in order.

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

-- ── World structure ──────────────────────────────────────────────────────────

assert(PuzzleLoader.world_count() >= 1, "expected at least one world")
assert(PuzzleLoader.count() >= 1, "expected at least one puzzle")

local next_index = 1
for w = 1, PuzzleLoader.world_count() do
    local world = PuzzleLoader.world(w)
    assert(type(world.name) == "string" and world.name ~= "",
        string.format("world %d has a non-empty name", w))
    assert(#world.puzzles >= 1, string.format("world %d has at least one puzzle", w))
    for i, p in ipairs(world.puzzles) do
        assert(p.index == next_index,
            string.format("world %d entry %d is puzzle %d", w, i, next_index))
        next_index = next_index + 1
    end
end
assert(PuzzleLoader.count() == next_index - 1, "no puzzle lies outside the worlds")
print("PASS: world structure")

print("ALL PUZZLE DATA TESTS PASSED")
