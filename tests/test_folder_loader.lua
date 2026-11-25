-- test_folder_loader.lua
-- PuzzleLoader builds worlds and puzzles from the folder layout. The folders
-- here are an in-memory tree, so the shipped data does not matter.

local PuzzleLoader = require("lua/game/puzzle_loader")

-- Runs fn with love.filesystem serving `tree`: a table is a folder, a string is
-- a file whose value is the puzzle name ("" for a puzzle without one).
-- Directory listings come back in reverse order, so nothing can rely on it.
local function with_tree(tree, fn)
    local orig_items = love.filesystem.getDirectoryItems
    local orig_load  = love.filesystem.load

    local function node(path)
        if path == "data/puzzles" then return tree end
        local rest = path:match("^data/puzzles/(.+)$")
        local at = tree
        for part in (rest or ""):gmatch("[^/]+") do
            at = type(at) == "table" and at[part] or nil
        end
        return rest and at
    end

    love.filesystem.getDirectoryItems = function(path)
        local at, items = node(path), {}
        if type(at) == "table" then
            for name in pairs(at) do items[#items + 1] = name end
        end
        table.sort(items, function(a, b) return a > b end)
        return items
    end
    love.filesystem.load = function(path)
        local file = node(path)
        if type(file) ~= "string" then return nil, "no such file" end
        return function() return { name = file ~= "" and file or nil } end
    end

    PuzzleLoader.rescan()
    local ok, err = pcall(fn)
    love.filesystem.getDirectoryItems = orig_items
    love.filesystem.load = orig_load
    PuzzleLoader.rescan()
    assert(ok, err)
end

local function eq(got, want, what)
    assert(got == want, string.format("%s: expected %s, got %s", what, tostring(want), tostring(got)))
end

local function ids()
    local out = {}
    for n = 1, PuzzleLoader.count() do out[n] = PuzzleLoader.id(n) end
    return table.concat(out, ",")
end

local function world_ids()
    local out = {}
    for w = 1, PuzzleLoader.world_count() do out[w] = PuzzleLoader.world_id(w) end
    return table.concat(out, ",")
end

-- ── Ordering ─────────────────────────────────────────────────────────────────

with_tree({
    ["zeta"]    = { ["a.lua"] = "A" },
    ["10_ten"]  = { ["b.lua"] = "B" },
    ["alpha"]   = { ["c.lua"] = "C" },
    ["2_two"]   = {
        ["zed.lua"]     = "Z",
        ["10_late.lua"] = "L",
        ["2_early.lua"] = "E",
        ["40_gap.lua"]  = "G",
        ["bare.lua"]    = "Br",
        ["7_yak.lua"]   = "Y",
        ["07_ant.lua"]  = "An",
    },
}, function()
    eq(world_ids(), "two,ten,alpha,zeta", "world order")
    eq(ids(), "early,ant,yak,late,gap,bare,zed,b,c,a", "puzzle order")
    eq(PuzzleLoader.path(1), "data/puzzles/2_two/2_early.lua", "path of first puzzle")
    eq(PuzzleLoader.path(6), "data/puzzles/2_two/bare.lua", "path of unprefixed puzzle")
    eq(PuzzleLoader.load(8).name, "B", "load follows the flattened order")
end)
print("PASS: numbered entries first, by number then name; the rest alphabetically")

with_tree({
    ["03_pear"]  = { ["a.lua"] = "A" },
    ["03_apple"] = { ["b.lua"] = "B" },
}, function()
    eq(world_ids(), "apple,pear", "equal folder numbers are ordered by name")
end)
print("PASS: equal numbers are ordered by name")

-- ── Names, ignored entries and lookups ───────────────────────────────────────

with_tree({
    ["05_fixed_pieces"] = {
        ["01_one.lua"]  = "One",
        ["02_two.lua"]  = "",
        ["notes.txt"]   = "ignored",
        ["one.lua.bak"] = "ignored",
        ["cutscene.lua"] = "scene",
    },
    ["06_plain"]    = { ["three.lua"] = "Three" },
    ["07_empty"]    = {},
    ["08_only_cut"] = { ["cutscene.lua"] = "scene" },
    ["09_text"]     = { ["readme.md"] = "ignored" },
    ["file.txt"]    = "a plain file",
    ["loose.lua"]   = "a loose puzzle",
}, function()
    eq(PuzzleLoader.world_count(), 2, "only folders with puzzles are worlds")
    eq(PuzzleLoader.count(), 3, "only world puzzles are counted")
    eq(ids(), "one,two,three", "puzzle ids")
    eq(world_ids(), "fixed_pieces,plain", "world ids")
    eq(PuzzleLoader.world(1).name, "Fixed Pieces", "world name")
    eq(PuzzleLoader.world(2).name, "Plain", "one-word world name")

    local puzzles = PuzzleLoader.world(1).puzzles
    eq(#puzzles, 2, "cutscene.lua is not a puzzle")
    eq(puzzles[1].index, 1, "first index")
    eq(puzzles[1].name, "One", "name from the file")
    eq(puzzles[2].name, "Puzzle 2", "missing name fallback")
    eq(PuzzleLoader.world(2).puzzles[1].index, 3, "indices run across worlds")

    local first = PuzzleLoader.world_indices(1)
    eq(table.concat(first, ","), "1,2", "world 1 indices")
    eq(table.concat(PuzzleLoader.world_indices(2), ","), "3", "world 2 indices")
    first[1] = 99
    eq(PuzzleLoader.world_indices(1)[1], 1, "world_indices returns a fresh array")
    for _, w in ipairs({ 0, 3 }) do
        local ok, err = pcall(PuzzleLoader.world_indices, w)
        assert(not ok and err:find("PuzzleLoader.world: index " .. w .. " out of range (1–2)", 1, true),
            "world_indices(" .. w .. ") out of range: " .. tostring(err))
    end

    for _, n in ipairs({ 0, -1, 4, 99, 1.5, "1" }) do
        eq(PuzzleLoader.id(n), nil, "id(" .. tostring(n) .. ")")
        eq(PuzzleLoader.path(n), nil, "path(" .. tostring(n) .. ")")
    end
    eq(PuzzleLoader.id(nil), nil, "id(nil)")
    eq(PuzzleLoader.path(nil), nil, "path(nil)")
    for _, w in ipairs({ 0, -1, 3, 99 }) do
        eq(PuzzleLoader.world_id(w), nil, "world_id(" .. w .. ")")
    end
    eq(PuzzleLoader.world_id(nil), nil, "world_id(nil)")

    eq(PuzzleLoader.cutscene_path(0), "data/cutscenes/world_0.lua", "intro cutscene")
    eq(PuzzleLoader.cutscene_path(1), "data/puzzles/05_fixed_pieces/cutscene.lua", "world cutscene")
    for _, w in ipairs({ 2, -1, 3, 99 }) do
        eq(PuzzleLoader.cutscene_path(w), nil, "cutscene_path(" .. w .. ")")
    end
    eq(PuzzleLoader.cutscene_path(nil), nil, "cutscene_path(nil)")
end)
print("PASS: names, ignored entries and lookups")

-- ── Duplicate ids ────────────────────────────────────────────────────────────

local function assert_duplicate(tree, message)
    with_tree(tree, function()
        -- Twice: a failed scan is not cached.
        for _ = 1, 2 do
            local ok, err = pcall(PuzzleLoader.count)
            assert(not ok and err:find(message, 1, true),
                "expected '" .. message .. "', got: " .. tostring(err))
        end
    end)
end

assert_duplicate({
    ["01_a"] = { ["01_flip.lua"] = "A" },
    ["02_b"] = { ["09_flip.lua"] = "B" },
}, "PuzzleLoader: duplicate puzzle id 'flip': "
    .. "'data/puzzles/01_a/01_flip.lua' and 'data/puzzles/02_b/09_flip.lua'")

assert_duplicate({
    ["01_basics"] = { ["a.lua"] = "A" },
    ["basics"]    = { ["b.lua"] = "B" },
}, "PuzzleLoader: duplicate world id 'basics': 'data/puzzles/01_basics' and 'data/puzzles/basics'")
print("PASS: duplicate ids name both paths")

-- World and puzzle ids are separate namespaces.
with_tree({ ["01_flip"] = { ["01_flip.lua"] = "Flip" } }, function()
    eq(PuzzleLoader.id(1), "flip", "puzzle id")
    eq(PuzzleLoader.world_id(1), "flip", "world id")
end)
print("PASS: a world and a puzzle may share an id")

print("ALL FOLDER LOADER TESTS PASSED")
