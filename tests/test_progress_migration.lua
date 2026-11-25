-- test_progress_migration.lua
-- Tests for the save migration in game/progress.lua: unversioned saves use the
-- old 23-puzzle numbering and are remapped once on load; version=2 saves are not.

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

-- Solved indices as a comma separated string; scans past both numberings.
local function solved_list(P)
    local out = {}
    for n = -1, 40 do
        if P.is_solved(n) then out[#out + 1] = tostring(n) end
    end
    return table.concat(out, ",")
end

local function range(last)
    local out = {}
    for n = 1, last do out[#out + 1] = tostring(n) end
    return table.concat(out, ",")
end

-- ── every remapped and dropped index ─────────────────────────────────────────

local REMAP = {
    [1] = 1,   [2] = 2,   [3] = 3,   [4] = 4,   [5] = 5,   [6] = 6,   [7] = 7,
    [8] = 8,   [9] = 9,   [10] = 10, [11] = 11, [12] = 12, [13] = 13, [14] = 14,
    [16] = 15, [18] = 16, [19] = 17, [20] = 18, [21] = 19, [22] = 20, [23] = 21,
}
local DROPPED = { -1, 0, 15, 17, 24, 99 }

local FORMATS = {
    { name = "solved table", make = function(list) return "return {solved={" .. list .. "},cutscenes={}}\n" end },
    { name = "plain array",  make = function(list) return "return {" .. list .. "}\n" end },
}

for _, format in ipairs(FORMATS) do
    for old, new in pairs(REMAP) do
        with_save(format.make(tostring(old)), function(P)
            assert(solved_list(P) == tostring(new), string.format(
                "%s: old %d must load as %d, got '%s'", format.name, old, new, solved_list(P)))
        end)
    end
    for _, old in ipairs(DROPPED) do
        with_save(format.make(tostring(old)), function(P)
            assert(solved_list(P) == "", string.format(
                "%s: old %d must be dropped, got '%s'", format.name, old, solved_list(P)))
        end)
    end

    -- The whole old range at once: remapping must not cascade or collide.
    local all = {}
    for n = 1, 23 do all[#all + 1] = tostring(n) end
    with_save(format.make(table.concat(all, ",")), function(P, writes)
        assert(solved_list(P) == range(21),
            format.name .. ": all 23 old puzzles load as 1..21, got " .. solved_list(P))
        assert(#writes == 0, format.name .. ": load must not write the save file")
    end)
    print("PASS: migration from " .. format.name)
end

-- Non-number entries are ignored.
with_save('return {"16",true,16}\n', function(P)
    assert(solved_list(P) == "15", "non-number entries ignored, got " .. solved_list(P))
end)
print("PASS: migration ignores non-number entries")

-- ── cutscene flags ───────────────────────────────────────────────────────────

with_save("return {solved={18},cutscenes={2,3}}\n", function(P)
    assert(solved_list(P) == "16", "solved index remapped")
    assert(P.is_cutscene_seen(2) and P.is_cutscene_seen(3), "cutscene flags copied")
    assert(not P.is_cutscene_seen(1), "unseen cutscene stays unseen")
    assert(not P.is_cutscene_seen(16), "cutscene flags are not solved indices")
end)
print("PASS: migration copies cutscene flags")

-- ── versioned save ───────────────────────────────────────────────────────────

with_save("return {version=2,solved={15,16,17,18,21},cutscenes={2}}\n", function(P, writes)
    assert(solved_list(P) == "15,16,17,18,21",
        "versioned save must not be remapped, got " .. solved_list(P))
    assert(P.is_cutscene_seen(2), "versioned save: cutscene loaded")
    assert(#writes == 0, "versioned save: load must not write the save file")
end)
print("PASS: versioned save left untouched")

-- ── written format ───────────────────────────────────────────────────────────

with_save("return {solved={16,23},cutscenes={2}}\n", function(P, writes)
    P.mark_solved(3)
    assert(#writes == 1, "mark_solved writes once")
    assert(writes[1].path == "progress.lua", "writes the save file")
    assert(writes[1].data == "return {version=2,solved={3,15,21},cutscenes={2}}\n",
        "unexpected save data: " .. writes[1].data)

    -- Loading what was written must not remap it a second time.
    with_save(writes[1].data, function(P2)
        assert(solved_list(P2) == "3,15,21", "round trip, got " .. solved_list(P2))
        assert(P2.is_cutscene_seen(2), "round trip keeps cutscenes")
    end)
end)
print("PASS: save is written with version=2 and round trips")

-- ── unlocked worlds are kept ─────────────────────────────────────────────────
-- Last puzzle index of worlds 1..5 in the old and new numbering. World N+1 is
-- unlocked when every puzzle up to the end of world N is solved.

local OLD_LAST = { 5, 11, 16, 20, 23 }
local NEW_LAST = { 5, 11, 15, 18, 21 }

for world = 1, #OLD_LAST do
    local list = range(OLD_LAST[world])
    for _, format in ipairs(FORMATS) do
        with_save(format.make(list), function(P)
            assert(solved_list(P) == range(NEW_LAST[world]), string.format(
                "%s: old worlds 1..%d must solve new 1..%d, got '%s'",
                format.name, world, NEW_LAST[world], solved_list(P)))
        end)
    end
end
print("PASS: solved worlds stay solved after migration")

assert(package.loaded["lua/game/progress"] == ORIG_MODULE, "original module restored")

print("ALL PROGRESS MIGRATION TESTS PASSED")
