-- test_worlds.lua
-- Every puzzle is reachable through exactly one world, fixed_player offers no
-- editable ops, and the transforms/fixed_pieces worlds lock according to the progression rule.

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

-- ── fixed_player has an empty ops list ──────────────────────────────────────────

local p19 = PuzzleLoader.load(S.puzzle("fixed_player"))
assert(type(p19.ops) == "table", "puzzle 19 ops is a table")
assert(next(p19.ops) == nil, "puzzle 19 ops is empty")
print("PASS: puzzle 19 ops is empty")

-- ── transforms unlocks after the worlds before it; fixed_pieces stays locked ──────────────────

assert(PuzzleLoader.world_count() >= 5, "at least 5 worlds")
Progress.reset()
local transforms, fixed_pieces = S.world("transforms"), S.world("fixed_pieces")
for w = 1, transforms - 1 do
    for _, p in ipairs(PuzzleLoader.world(w).puzzles) do
        Progress.mark_solved(p.index)
    end
end
assert(Progress.is_world_unlocked(transforms), "transforms unlocked after earlier worlds solved")
assert(not Progress.is_world_unlocked(fixed_pieces), "fixed_pieces locked while transforms unsolved")
print("PASS: transforms unlocked, fixed_pieces locked after earlier worlds solved")

Progress.reset()
print("ALL WORLDS TESTS PASSED")
