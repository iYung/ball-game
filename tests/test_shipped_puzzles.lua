-- test_shipped_puzzles.lua
-- Rules every shipped puzzle, world and cutscene must follow. Nothing here pins
-- counts or names, so adding a level does not require editing this file.

local PuzzleLoader = require("lua/game/puzzle_loader")

local MAX_PER_WORLD = 10  -- what fits on the level select screen

local function non_empty_string(value)
    return type(value) == "string" and value ~= ""
end

-- ── Layout ───────────────────────────────────────────────────────────────────

for _, name in ipairs(love.filesystem.getDirectoryItems("data/puzzles")) do
    assert(name:sub(-4) ~= ".lua", string.format(
        "data/puzzles/%s belongs to no world: move it into a world folder", name))
end
print("PASS: no puzzle file outside a world folder")

for w = 1, PuzzleLoader.world_count() do
    local total = #PuzzleLoader.world_indices(w)
    assert(total <= MAX_PER_WORLD, string.format(
        "world '%s' has %d puzzles, at most %d fit on the level select screen",
        tostring(PuzzleLoader.world_id(w)), total, MAX_PER_WORLD))
    assert(non_empty_string(PuzzleLoader.world_id(w)),
        string.format("world %d has a string id", w))
end
print("PASS: every world has an id and at most " .. MAX_PER_WORLD .. " puzzles")

-- ── Puzzles ──────────────────────────────────────────────────────────────────

for n = 1, PuzzleLoader.count() do
    local path = PuzzleLoader.path(n)
    assert(type(path) == "string" and path:match("^data/puzzles/[^/]+/[^/]+%.lua$"),
        string.format("puzzle %d lies in a world folder, got %s", n, tostring(path)))
    assert(non_empty_string(PuzzleLoader.id(n)), path .. " has a string id")
    assert(non_empty_string(PuzzleLoader.load(n).name),
        path .. " needs a non-empty string name")
end
print("PASS: every puzzle has an id, a world folder and a name")

-- ── Cutscenes ────────────────────────────────────────────────────────────────

for w = 0, PuzzleLoader.world_count() do
    local path = PuzzleLoader.cutscene_path(w)
    if path then
        local chunk, err = love.filesystem.load(path)
        assert(chunk, string.format("could not load '%s': %s", path, tostring(err)))
        local beats = chunk()
        assert(type(beats) == "table" and next(beats) ~= nil,
            path .. " must return a non-empty table")
    end
end
print("PASS: every cutscene loads")

for _, name in ipairs(love.filesystem.getDirectoryItems("data/cutscenes")) do
    assert(name == "world_0.lua", string.format(
        "data/cutscenes/%s is never played: a world's cutscene is cutscene.lua in its folder", name))
end
print("PASS: data/cutscenes holds only the intro")

print("ALL SHIPPED PUZZLE TESTS PASSED")
