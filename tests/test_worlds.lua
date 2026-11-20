-- test_worlds.lua
-- Every puzzle is reachable through exactly one world, puzzle 21 offers no
-- editable ops, and worlds 4/5 lock according to the progression rule.

local PuzzleLoader = require("lua/game/puzzle_loader")
local Progress     = require("lua/game/progress")

-- ── Reachability: every index 1..count() is in exactly one world ─────────────

local hits = {}
for w = 1, PuzzleLoader.world_count() do
    for _, p in ipairs(PuzzleLoader.world(w).puzzles) do
        hits[p.index] = (hits[p.index] or 0) + 1
    end
end
for i = 1, PuzzleLoader.count() do
    assert(hits[i] == 1, string.format("puzzle %d appears in %d worlds (expected 1)", i, hits[i] or 0))
end
print("PASS: every puzzle 1.." .. PuzzleLoader.count() .. " is in exactly one world")

-- ── Puzzle 21 has an empty ops list ──────────────────────────────────────────

local p21 = PuzzleLoader.load(21)
assert(type(p21.ops) == "table", "puzzle 21 ops is a table")
assert(next(p21.ops) == nil, "puzzle 21 ops is empty")
print("PASS: puzzle 21 ops is empty")

-- ── World 4 unlocks after worlds 1-3; world 5 stays locked ──────────────────

assert(PuzzleLoader.world_count() >= 5, "at least 5 worlds")
Progress.reset()
for w = 1, 3 do
    for _, p in ipairs(PuzzleLoader.world(w).puzzles) do
        Progress.mark_solved(p.index)
    end
end
assert(Progress.is_world_unlocked(4), "world 4 unlocked after worlds 1-3 solved")
assert(not Progress.is_world_unlocked(5), "world 5 locked while world 4 unsolved")
print("PASS: world 4 unlocked, world 5 locked after worlds 1-3 solved")

Progress.reset()
print("ALL WORLDS TESTS PASSED")
