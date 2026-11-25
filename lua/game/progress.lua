local PuzzleLoader = require("lua/game/puzzle_loader")

local SAVE_FILE = "progress.lua"

-- Puzzle positions shift when a level is added, so progress is keyed and saved
-- by puzzle and world id (version 3). Older saves hold numbers: version 2 holds
-- today's positions, unversioned ones the old 23-puzzle numbering.
local SAVE_VERSION = 3

-- Old index -> new index. Old puzzles 15 and 17 were deleted, so they (and any
-- index not listed) are dropped.
local V1_TO_V2 = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
    [16] = 15, [18] = 16, [19] = 17, [20] = 18,
    [21] = 19, [22] = 20, [23] = 21,
}

-- Version 2 number -> id. These describe old saves, not the current folders:
-- never change them, even when levels are added, moved or removed.
local V2_PUZZLE_IDS = {
    "identity", "flip", "negate", "swap", "scale", "row_swap", "double_flip",
    "combo", "uturn", "set_row", "rotate_gap", "negate_swap", "flip_scale",
    "elimination", "triple", "col_ops", "flips", "double_negative",
    "fixed_player", "fixed_puzzle", "locked_scale",
}
local V2_WORLD_IDS = {
    [0] = 0, "basics", "combos", "advanced", "transforms", "fixed_pieces",
}

-- Keys are ids. A number with no puzzle or world behind it is its own key, so it
-- reads back during this session but is never written (except cutscene 0).
local _solved         = {}  -- set: _solved[key] = true if the puzzle is solved
local _seen_cutscene  = {}  -- set: _seen_cutscene[key] = true if the cutscene has been seen

local function _puzzle_key(n)
    return PuzzleLoader.id(n) or n
end

-- 0 is the intro cutscene, which belongs to no world.
local function _world_key(w)
    if w == 0 then return 0 end
    return PuzzleLoader.world_id(w) or w
end

-- The ids in a set, quoted and sorted alphabetically.
local function _quoted_ids(set)
    local ids = {}
    for key, v in pairs(set) do
        if v and type(key) == "string" then ids[#ids + 1] = key end
    end
    table.sort(ids)
    for i, id in ipairs(ids) do ids[i] = string.format("%q", id) end
    return ids
end

local function _persist()
    if not love.filesystem or not love.filesystem.write then return end
    local cutscene_parts = _quoted_ids(_seen_cutscene)
    if _seen_cutscene[0] then table.insert(cutscene_parts, 1, "0") end

    local data = string.format(
        "return {version=%d,solved={%s},cutscenes={%s}}\n",
        SAVE_VERSION,
        table.concat(_quoted_ids(_solved), ","),
        table.concat(cutscene_parts, ",")
    )
    local ok, err = pcall(love.filesystem.write, SAVE_FILE, data)
    if not ok then
        -- silently ignore write failures (e.g. headless)
        _ = err
    end
end

local function _load()
    if not love.filesystem or not love.filesystem.read then return end
    if love.filesystem.getInfo and not love.filesystem.getInfo(SAVE_FILE) then return end
    local ok, data = pcall(love.filesystem.read, SAVE_FILE)
    if not ok or type(data) ~= "string" then return end
    local chunk, err = (loadstring or load)(data)
    if not chunk then return end
    local ok2, tbl = pcall(chunk)
    if not ok2 or type(tbl) ~= "table" then return end
    -- Table format: {version=3, solved={...}, cutscenes={...}}. Version 2 has
    -- the same shape with numbers, and older saves have no version. Oldest
    -- format: plain array {1,2,3,...} of solved.
    if tbl.version == SAVE_VERSION then
        -- Ids with no matching file are kept, so a level that returns is still solved.
        for _, id in ipairs(tbl.solved or {}) do
            if type(id) == "string" then _solved[id] = true end
        end
        for _, id in ipairs(tbl.cutscenes or {}) do
            if id == 0 or type(id) == "string" then _seen_cutscene[id] = true end
        end
        return
    end
    -- Converted through the constant tables only, never the loader.
    for _, n in ipairs(tbl.solved or tbl) do
        if type(n) == "number" then
            if not tbl.version then n = V1_TO_V2[n] end
            local id = n and V2_PUZZLE_IDS[n]
            if id then _solved[id] = true end
        end
    end
    for _, w in ipairs(tbl.cutscenes or {}) do
        if type(w) == "number" then
            local id = V2_WORLD_IDS[w]
            if id then _seen_cutscene[id] = true end
        end
    end
end

_load()

local Progress = {}

function Progress.mark_solved(n)
    local key = _puzzle_key(n)
    if _solved[key] then return end
    _solved[key] = true
    _persist()
end

function Progress.is_solved(n)
    return _solved[_puzzle_key(n)] == true
end

local function _world_solved(w)
    for _, n in ipairs(PuzzleLoader.world_indices(w)) do
        if not Progress.is_solved(n) then return false end
    end
    return true
end

local function _any_solved_from(w)
    for later = w, PuzzleLoader.world_count() do
        for _, n in ipairs(PuzzleLoader.world_indices(later)) do
            if Progress.is_solved(n) then return true end
        end
    end
    return false
end

-- Open if first, if all earlier worlds are complete, or if the player has solved
-- something here or later (so a newly added level never locks them out).
-- Runs every frame: use world_indices, which loads no puzzle files.
function Progress.is_world_unlocked(w)
    if w == 1 or _any_solved_from(w) then return true end
    for prev = 1, w - 1 do
        if not _world_solved(prev) then return false end
    end
    return true
end

function Progress.unlock_world(w)
    for _, n in ipairs(PuzzleLoader.world_indices(w)) do
        _solved[_puzzle_key(n)] = true
    end
    -- Clear the first-visit cutscene for the world that just became accessible,
    -- so a tester pressing U can still see the full first-visit flow.
    _seen_cutscene[_world_key(w + 1)] = nil
    _persist()
end

function Progress.unlock_all()
    for n = 1, PuzzleLoader.count() do
        _solved[_puzzle_key(n)] = true
    end
    _persist()
end

function Progress.is_cutscene_seen(w)
    return _seen_cutscene[_world_key(w)] == true
end

function Progress.mark_cutscene_seen(w)
    local key = _world_key(w)
    if _seen_cutscene[key] then return end
    _seen_cutscene[key] = true
    _persist()
end

function Progress.reset()
    _solved = {}
    _seen_cutscene = {}
    _persist()
end

return Progress
