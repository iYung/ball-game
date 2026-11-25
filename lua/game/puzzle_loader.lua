-- Worlds and puzzles come from the folder layout: every folder in data/puzzles/
-- that holds a puzzle is a world, and every .lua file in it (except
-- cutscene.lua) is a puzzle.

local ROOT     = "data/puzzles"
local CUTSCENE = "cutscene.lua"
local INTRO    = "data/cutscenes/world_0.lua"

local PuzzleLoader = {}

local _cache = nil  -- { puzzles = { { id, path } }, worlds = { ... } }

-- Sort entry for a folder name, or a file name with ".lua" already stripped.
local function _entry(raw, stripped)
    local prefix, rest = stripped:match("^(%d+)_(.+)$")
    return { raw = raw, stripped = stripped, num = tonumber(prefix), id = rest or stripped }
end

-- Numbered entries first, by number; then the rest, alphabetically.
local function _before(a, b)
    if a.num ~= b.num then
        if a.num and b.num then return a.num < b.num end
        return a.num ~= nil
    end
    -- The stripped name also settles the raw name: they differ only by ".lua".
    return a.stripped < b.stripped
end

local function _title(id)
    return (id:gsub("_", " "):gsub("%S+", function(word)
        return word:sub(1, 1):upper() .. word:sub(2)
    end))
end

local function _claim(seen, kind, id, path)
    if seen[id] then
        error(string.format("PuzzleLoader: duplicate %s id '%s': '%s' and '%s'", kind, id, seen[id], path))
    end
    seen[id] = path
end

-- Only lists directories: it never loads a file.
local function _scan()
    if _cache then return _cache end

    local folders = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(ROOT)) do
        local folder = _entry(name, name)
        folder.path  = ROOT .. "/" .. name
        folder.files = {}
        for _, file in ipairs(love.filesystem.getDirectoryItems(folder.path)) do
            if file == CUTSCENE then
                folder.cutscene = folder.path .. "/" .. file
            elseif file:sub(-4) == ".lua" then
                folder.files[#folder.files + 1] = _entry(file, file:sub(1, -5))
            end
        end
        if #folder.files > 0 then folders[#folders + 1] = folder end
    end
    table.sort(folders, _before)

    local scan = { puzzles = {}, worlds = {} }
    local world_ids, puzzle_ids = {}, {}
    for _, folder in ipairs(folders) do
        _claim(world_ids, "world", folder.id, folder.path)
        local world = { id = folder.id, name = _title(folder.id), cutscene = folder.cutscene, indices = {} }
        table.sort(folder.files, _before)
        for _, file in ipairs(folder.files) do
            local path = folder.path .. "/" .. file.raw
            _claim(puzzle_ids, "puzzle", file.id, path)
            local n = #scan.puzzles + 1
            scan.puzzles[n] = { id = file.id, path = path }
            world.indices[#world.indices + 1] = n
        end
        scan.worlds[#scan.worlds + 1] = world
    end

    _cache = scan  -- only after a full scan, so a duplicate errors every time
    return scan
end

-- The world record for w, erroring when w is out of range.
local function _checked_world(w)
    local worlds = _scan().worlds
    if type(w) ~= "number" or w < 1 or w > #worlds then
        error(string.format("PuzzleLoader.world: index %s out of range (1–%d)", tostring(w), #worlds))
    end
    return worlds[w]
end

function PuzzleLoader.rescan()
    _cache = nil
end

function PuzzleLoader.world_count()
    return #_scan().worlds
end

function PuzzleLoader.world_indices(w)
    return { unpack(_checked_world(w).indices) }
end

function PuzzleLoader.world(w)
    local def = _checked_world(w)
    local result = { name = def.name, puzzles = {} }
    for _, idx in ipairs(def.indices) do
        result.puzzles[#result.puzzles + 1] = {
            index = idx,
            name  = PuzzleLoader.load(idx).name or ("Puzzle " .. idx),
        }
    end
    return result
end

function PuzzleLoader.world_id(w)
    local world = _scan().worlds[w]
    return world and world.id
end

function PuzzleLoader.cutscene_path(w)
    if w == 0 then return INTRO end
    local world = _scan().worlds[w]
    return world and world.cutscene
end

function PuzzleLoader.id(n)
    local puzzle = _scan().puzzles[n]
    return puzzle and puzzle.id
end

function PuzzleLoader.path(n)
    local puzzle = _scan().puzzles[n]
    return puzzle and puzzle.path
end

function PuzzleLoader.load(n)
    local puzzles = _scan().puzzles
    if type(n) ~= "number" or n < 1 or n > #puzzles then
        error(string.format("PuzzleLoader.load: index %s out of range (1–%d)", tostring(n), #puzzles))
    end
    local path = puzzles[n].path
    local chunk, err = love.filesystem.load(path)
    if not chunk then
        error(string.format("PuzzleLoader.load: could not load '%s': %s", path, tostring(err)))
    end
    return chunk()
end

function PuzzleLoader.count()
    return #_scan().puzzles
end

return PuzzleLoader
