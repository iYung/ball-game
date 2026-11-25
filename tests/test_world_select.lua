local PuzzleLoader = require("lua/game/puzzle_loader")

-- world_count returns a positive integer
local n = PuzzleLoader.world_count()
assert(type(n) == "number" and n >= 1, "world_count returns a positive number")
print("PASS: world_count returns " .. n)

-- world() returns expected structure for each world
local all_indices = {}
for w = 1, n do
    local world = PuzzleLoader.world(w)
    assert(type(world.name) == "string" and #world.name > 0,
        string.format("world %d has a non-empty name", w))
    assert(type(world.puzzles) == "table" and #world.puzzles > 0,
        string.format("world %d has at least one puzzle", w))
    for _, p in ipairs(world.puzzles) do
        assert(type(p.index) == "number", string.format("world %d puzzle entry has numeric index", w))
        assert(type(p.name)  == "string", string.format("world %d puzzle entry has string name", w))
        all_indices[#all_indices + 1] = p.index
    end
    print(string.format("PASS: world %d (%s) has %d puzzles", w, world.name, #world.puzzles))
end

-- all puzzle indices are unique and within range
local seen = {}
for _, idx in ipairs(all_indices) do
    assert(idx >= 1 and idx <= PuzzleLoader.count(),
        string.format("puzzle index %d is in valid range 1–%d", idx, PuzzleLoader.count()))
    assert(not seen[idx], string.format("puzzle index %d appears in more than one world", idx))
    seen[idx] = true
end
print("PASS: all puzzle indices unique and in range")

-- out-of-range world raises an error
local ok = pcall(PuzzleLoader.world, 0)
assert(not ok, "world(0) should raise")
ok = pcall(PuzzleLoader.world, n + 1)
assert(not ok, "world(n+1) should raise")
print("PASS: out-of-range world raises error")

-- existing API untouched
assert(type(PuzzleLoader.count) == "function", "count() still exists")
assert(type(PuzzleLoader.load)  == "function", "load() still exists")
assert(PuzzleLoader.count() == #all_indices,
    "count() equals the number of puzzles across all worlds")
print("PASS: existing API unchanged")

print("ALL WORLD SELECT TESTS PASSED")
