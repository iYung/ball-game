-- test_progress_ids.lua
-- Tests for saves keyed by id (version 3) and the unlock rule in game/progress.lua.

local PuzzleLoader = require("lua/game/puzzle_loader")

local ORIG_MODULE = package.loaded["lua/game/progress"]

-- Load a fresh Progress module against a fake save file, run fn(P, writes), then
-- restore the filesystem stubs and the original module. love.filesystem.write is
-- captured the whole time, so no real save file can be touched.
local function with_save(contents, fn)
    local orig_getInfo = love.filesystem.getInfo
    local orig_read    = love.filesystem.read
    local orig_write   = love.filesystem.write
    local writes       = {}

    love.filesystem.getInfo = function(path)
        if path == "progress.lua" then return { type = "file" } end
        return orig_getInfo(path)
    end
    love.filesystem.read = function(path)
        if path == "progress.lua" then return contents end
        return orig_read(path)
    end
    love.filesystem.write = function(path, data)
        writes[#writes + 1] = { path = path, data = data }
    end

    package.loaded["lua/game/progress"] = nil
    local ok, err = pcall(function()
        fn(require("lua/game/progress"), writes)
    end)

    love.filesystem.getInfo = orig_getInfo
    love.filesystem.read    = orig_read
    love.filesystem.write   = orig_write
    package.loaded["lua/game/progress"] = ORIG_MODULE
    assert(ok, err)
end

-- Run fn with change(path, items) applied to every directory listing the loader
-- reads, then restore the real listing.
local function with_listing(change, fn)
    local orig = love.filesystem.getDirectoryItems
    love.filesystem.getDirectoryItems = function(path)
        return change(path, orig(path))
    end
    PuzzleLoader.rescan()
    local ok, err = pcall(fn)
    love.filesystem.getDirectoryItems = orig
    PuzzleLoader.rescan()
    assert(ok, err)
end

local function position(id)
    for n = 1, PuzzleLoader.count() do
        if PuzzleLoader.id(n) == id then return n end
    end
    error("no puzzle with id " .. id)
end

local function world_number(id)
    for w = 1, PuzzleLoader.world_count() do
        if PuzzleLoader.world_id(w) == id then return w end
    end
    error("no world with id " .. id)
end

-- The folder holding a puzzle, e.g. "data/puzzles/01_basics".
local function folder_of(id)
    return (PuzzleLoader.path(position(id)):match("^(.*)/[^/]+$"))
end

-- ── version 3 load and round trip ────────────────────────────────────────────

local V3 = 'return {version=3,solved={"flip","identity"},cutscenes={0,"combos"}}\n'

with_save(V3, function(P, writes)
    assert(P.is_solved(position("identity")), "identity loaded")
    assert(P.is_solved(position("flip")), "flip loaded")
    assert(not P.is_solved(position("negate")), "negate not in save")
    assert(P.is_cutscene_seen(0), "intro loaded")
    assert(P.is_cutscene_seen(world_number("combos")), "combos cutscene loaded")
    assert(not P.is_cutscene_seen(world_number("advanced")), "advanced cutscene unseen")
    assert(#writes == 0, "load must not write the save file")

    -- Marking something already known writes nothing.
    P.mark_solved(position("flip"))
    P.mark_cutscene_seen(0)
    P.mark_cutscene_seen(world_number("combos"))
    assert(#writes == 0, "no change, no write")

    P.mark_solved(position("negate"))
    P.mark_cutscene_seen(world_number("advanced"))
    local data = writes[#writes].data
    assert(writes[#writes].path == "progress.lua", "writes the save file")
    assert(data == 'return {version=3,solved={"flip","identity","negate"},cutscenes={0,"advanced","combos"}}\n',
        "unexpected save data: " .. data)

    with_save(data, function(P2, writes2)
        P2.mark_solved(position("swap"))
        assert(writes2[1].data ==
            'return {version=3,solved={"flip","identity","negate","swap"},cutscenes={0,"advanced","combos"}}\n',
            "round trip, got " .. writes2[1].data)
    end)
end)
print("PASS: version 3 save loads and round trips")

with_save("return {version=3,solved={},cutscenes={}}\n", function(P, writes)
    P.mark_cutscene_seen(0)
    assert(writes[1].data == "return {version=3,solved={},cutscenes={0}}\n",
        "unexpected save data: " .. writes[1].data)
end)
with_save("return {version=3}\n", function(P, writes)
    assert(not P.is_solved(1) and not P.is_cutscene_seen(0), "nothing loaded")
    P.reset()
    assert(writes[1].data == "return {version=3,solved={},cutscenes={}}\n",
        "unexpected save data: " .. writes[1].data)
end)
print("PASS: empty version 3 save")

-- ── unknown ids survive a rewrite ────────────────────────────────────────────

with_save('return {version=3,solved={"zz_removed"},cutscenes={"zz_gone"}}\n', function(P, writes)
    P.mark_solved(position("identity"))
    assert(writes[1].data ==
        'return {version=3,solved={"identity","zz_removed"},cutscenes={"zz_gone"}}\n',
        "unknown ids must be kept, got " .. writes[1].data)
end)
print("PASS: unknown ids are kept")

-- ── wrong-typed version 3 entries ────────────────────────────────────────────

with_save('return {version=3,solved={1,0,true,{},"flip"},cutscenes={2,true,{},"combos",0}}\n',
    function(P, writes)
        assert(not P.is_solved(position("identity")), "number 1 is not a solved entry")
        assert(not P.is_solved(0), "number 0 ignored")
        assert(not P.is_cutscene_seen(99), "no stray cutscene")
        P.mark_solved(position("identity"))
        assert(writes[1].data == 'return {version=3,solved={"flip","identity"},cutscenes={0,"combos"}}\n',
            "wrong types must be ignored, got " .. writes[1].data)
    end)
print("PASS: wrong-typed version 3 entries ignored")

-- ── conversion of old saves ──────────────────────────────────────────────────

local function numbers(first, last)
    local out = {}
    for n = first, last do out[#out + 1] = tostring(n) end
    return table.concat(out, ",")
end

local ALL_PUZZLES = '"col_ops","combo","double_flip","double_negative","elimination",'
    .. '"fixed_player","fixed_puzzle","flip","flip_scale","flips","identity",'
    .. '"locked_scale","negate","negate_swap","rotate_gap","row_swap","scale",'
    .. '"set_row","swap","triple","uturn"'
local ALL_WORLDS = '0,"advanced","basics","combos","fixed_pieces","transforms"'

-- The loader sees no puzzles at all here: conversion must not depend on it.
with_listing(function() return {} end, function()
    with_save("return {version=2,solved={" .. numbers(-1, 40) .. "},cutscenes={" .. numbers(-1, 9) .. "}}\n",
        function(P, writes)
            assert(#writes == 0, "load must not write the save file")
            P.mark_cutscene_seen(99)
            assert(writes[1].data ==
                "return {version=3,solved={" .. ALL_PUZZLES .. "},cutscenes={" .. ALL_WORLDS .. "}}\n",
                "unexpected conversion: " .. writes[1].data)
        end)
end)
print("PASS: version 2 conversion table")

with_save("return {version=2,solved={},cutscenes={0,2,5,9}}\n", function(P, writes)
    assert(P.is_cutscene_seen(0), "intro stays 0")
    assert(P.is_cutscene_seen(world_number("combos")), "2 is combos")
    assert(P.is_cutscene_seen(world_number("fixed_pieces")), "5 is fixed_pieces")
    assert(not P.is_cutscene_seen(world_number("basics")), "basics unseen")
    P.mark_solved(position("identity"))
    assert(writes[1].data ==
        'return {version=3,solved={"identity"},cutscenes={0,"combos","fixed_pieces"}}\n',
        "9 must be dropped, got " .. writes[1].data)
end)
print("PASS: version 2 cutscenes convert")

with_save('return {version=2,solved={"flip",true,3},cutscenes={"combos",true}}\n', function(P, writes)
    P.mark_solved(position("identity"))
    assert(writes[1].data == 'return {version=3,solved={"identity","negate"},cutscenes={}}\n',
        "only numbers count in version 2, got " .. writes[1].data)
end)
print("PASS: version 2 ignores non-numbers")

-- ── numeric fallback keys ────────────────────────────────────────────────────

with_save("return {version=3,solved={},cutscenes={}}\n", function(P, writes)
    P.mark_solved(0)
    P.mark_solved(99)
    P.mark_cutscene_seen(99)
    P.mark_cutscene_seen(0)
    P.mark_solved(position("identity"))
    assert(P.is_solved(0) and P.is_solved(99), "numeric keys read back this session")
    assert(P.is_cutscene_seen(99), "numeric cutscene key reads back this session")
    assert(writes[#writes].data == 'return {version=3,solved={"identity"},cutscenes={0}}\n',
        "numeric keys must not be written, got " .. writes[#writes].data)
end)
print("PASS: numeric fallback keys are not written")

-- ── a saved id follows its puzzle ────────────────────────────────────────────

do
    local before = position("flip")
    local world  = world_number("combos")
    local folder = folder_of("flip")

    with_save('return {version=3,solved={"flip"},cutscenes={"combos"}}\n', function(P)
        assert(P.is_solved(before), "solved at its first position")
        with_listing(function(path, items)
            if path == folder then items[#items + 1] = "00_zz_inserted.lua" end
            if path == "data/puzzles" then items[#items + 1] = "00_zz_world" end
            if path == "data/puzzles/00_zz_world" then return { "01_zz_other.lua" } end
            return items
        end, function()
            local after = position("flip")
            assert(after == before + 2, "flip moved two places, now " .. after)
            assert(P.is_solved(after), "solved at its new position")
            assert(not P.is_solved(position("zz_inserted")), "inserted puzzle is unsolved")
            assert(not P.is_solved(position("identity")), "neighbour is unsolved")
            assert(world_number("combos") == world + 1, "world moved")
            assert(P.is_cutscene_seen(world + 1), "cutscene follows its world")
            assert(not P.is_cutscene_seen(world), "old world number is unseen")
        end)
    end)
end
print("PASS: saved ids follow puzzles and worlds")

-- ── unlock rule ──────────────────────────────────────────────────────────────

local EMPTY = "return {version=3,solved={},cutscenes={}}\n"

with_save(EMPTY, function(P)
    assert(P.is_world_unlocked(1), "first world open")
    for w = 2, PuzzleLoader.world_count() do
        assert(not P.is_world_unlocked(w), "nothing solved: world " .. w .. " locked")
    end
end)
print("PASS: nothing solved opens only the first world")

with_save('return {version=3,solved={"negate_swap"},cutscenes={}}\n', function(P)
    local last = world_number("advanced")
    for w = 1, last do
        assert(P.is_world_unlocked(w), "world " .. w .. " open: solve here or later")
    end
    assert(not P.is_world_unlocked(last + 1), "the next world stays locked")
end)
print("PASS: a solve opens its world and all earlier ones")

with_save(EMPTY, function(P)
    local target = world_number("transforms")
    local last
    for w = 1, target - 1 do
        for _, n in ipairs(PuzzleLoader.world_indices(w)) do
            if last then P.mark_solved(last) end
            last = n
        end
    end
    assert(not P.is_world_unlocked(target), "one earlier puzzle unsolved: locked")
    P.mark_solved(last)
    assert(P.is_world_unlocked(target), "all earlier solved: open")
    assert(not P.is_world_unlocked(target + 1), "the one after stays locked")
end)
print("PASS: completing all earlier worlds opens the next")

do
    local folder = folder_of("identity")
    local function add_level(path, items)
        if path == folder then items[#items + 1] = "99_zz_new.lua" end
        return items
    end

    -- A solve in the world itself, or in a later one, keeps it open.
    for _, solved in ipairs({ "row_swap", "negate_swap" }) do
        with_save('return {version=3,solved={"' .. solved .. '"},cutscenes={}}\n', function(P)
            with_listing(add_level, function()
                assert(not P.is_solved(position("zz_new")), "new level unsolved")
                assert(P.is_world_unlocked(world_number("combos")),
                    "new level must not lock a world with " .. solved .. " solved")
            end)
        end)
    end

    -- The limit: with nothing solved there or later, the world locks again.
    with_save(EMPTY, function(P)
        local world = world_number("combos")
        for w = 1, world - 1 do P.unlock_world(w) end
        assert(P.is_world_unlocked(world), "open before the new level")
        with_listing(add_level, function()
            assert(not P.is_world_unlocked(world_number("combos")), "locked until the new level is solved")
        end)
    end)
end
print("PASS: a new level does not lock players out")

-- is_world_unlocked runs every frame, so it must not load puzzle files.
with_save(EMPTY, function(P)
    local orig = love.filesystem.load
    love.filesystem.load = function(path) error("loaded " .. path) end
    local ok, err = pcall(function()
        for w = 1, PuzzleLoader.world_count() do P.is_world_unlocked(w) end
    end)
    love.filesystem.load = orig
    assert(ok, err)
end)
print("PASS: unlock check loads no files")

-- ── unlock_world, unlock_all, reset ──────────────────────────────────────────

with_save('return {version=3,solved={},cutscenes={"combos","advanced"}}\n', function(P, writes)
    local before_combos = world_number("combos") - 1  -- unlocking it clears combos
    P.unlock_world(before_combos)
    assert(writes[#writes].data:find('cutscenes={"advanced"}', 1, true),
        "unexpected save data: " .. writes[#writes].data)
    for _, n in ipairs(PuzzleLoader.world_indices(before_combos)) do
        assert(P.is_solved(n), "puzzle " .. n .. " solved by unlock_world")
    end
    assert(not P.is_cutscene_seen(world_number("combos")), "next world's cutscene cleared")
    assert(P.is_cutscene_seen(world_number("advanced")), "other cutscene kept")

    -- The last world has no next world to clear.
    P.unlock_world(PuzzleLoader.world_count())
    P.unlock_all()
    for n = 1, PuzzleLoader.count() do
        assert(P.is_solved(n), "puzzle " .. n .. " solved by unlock_all")
    end
    P.reset()
    assert(writes[#writes].data == "return {version=3,solved={},cutscenes={}}\n",
        "reset clears the save, got " .. writes[#writes].data)
end)
print("PASS: unlock_world, unlock_all and reset")

assert(package.loaded["lua/game/progress"] == ORIG_MODULE, "original module restored")

print("ALL PROGRESS ID TESTS PASSED")
