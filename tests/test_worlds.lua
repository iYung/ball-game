-- test_worlds.lua
-- Every puzzle is reachable through exactly one world, add_only offers no
-- editable ops, and the advanced/two_sources worlds lock according to the progression rule.

local S = require("tests/support/shipped")
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

-- ── add_only has an empty ops list ──────────────────────────────────────────────

local add_only = PuzzleLoader.load(S.puzzle("add_only"))
assert(type(add_only.ops) == "table", "add_only ops is a table")
assert(next(add_only.ops) == nil, "add_only ops is empty")
print("PASS: add_only ops is empty")

-- ── advanced unlocks after the worlds before it; two_sources stays locked ──────────────────

assert(PuzzleLoader.world_count() >= 4, "at least 4 worlds")
Progress.reset()
local advanced, two_sources = S.world("advanced"), S.world("two_sources")
for _, n in ipairs(S.before(advanced)) do
    Progress.mark_solved(n)
end
assert(Progress.is_world_unlocked(advanced), "advanced unlocked after earlier worlds solved")
assert(not Progress.is_world_unlocked(two_sources), "two_sources locked while advanced unsolved")
print("PASS: advanced unlocked, two_sources locked after earlier worlds solved")

Progress.reset()
print("ALL WORLDS TESTS PASSED")
